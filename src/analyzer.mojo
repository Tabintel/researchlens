from std.sys import argv
from std.time import perf_counter_ns

comptime SIMD_WIDTH = 32


def is_ascii_word_byte(byte: UInt8) -> Bool:
    return (
        (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or byte == 95
    )


def term_matches_at(
    data: Span[UInt8, _], term: Span[UInt8, _], start: Int
) -> Bool:
    if len(term) == 0 or start < 0 or start + len(term) > len(data):
        return False

    for index in range(len(term)):
        if data[start + index] != term[index]:
            return False

    if start > 0 and is_ascii_word_byte(data[start - 1]):
        return False

    var end = start + len(term)
    if end < len(data) and is_ascii_word_byte(data[end]):
        return False

    return True


def count_term_scalar(data: Span[UInt8, _], term: Span[UInt8, _]) -> Int:
    if len(term) == 0 or len(term) > len(data):
        return 0

    var count = 0
    var limit = len(data) - len(term) + 1
    for start in range(limit):
        if term_matches_at(data, term, start):
            count += 1
    return count


def count_term_simd(data: Span[UInt8, _], term: Span[UInt8, _]) -> Int:
    if len(term) == 0 or len(term) > len(data):
        return 0

    var count = 0
    var limit = len(data) - len(term) + 1
    var offset = 0
    var first = term[0]
    var ptr = data.unsafe_ptr()

    while offset + SIMD_WIDTH <= limit:
        var chunk = ptr.unsafe_load[width=SIMD_WIDTH](offset)
        var candidates = chunk.eq(
            SIMD[DType.uint8, SIMD_WIDTH](first)
        )

        for lane in range(SIMD_WIDTH):
            if candidates[lane] and term_matches_at(
                data, term, offset + lane
            ):
                count += 1
        offset += SIMD_WIDTH

    # The guarded scalar tail makes the final partial chunk safe.
    while offset < limit:
        if data[offset] == first and term_matches_at(data, term, offset):
            count += 1
        offset += 1

    return count


def benchmark(
    data: Span[UInt8, _], term: Span[UInt8, _], iterations: Int
) -> None:
    var scalar_result = count_term_scalar(data, term)
    var simd_result = count_term_simd(data, term)
    if scalar_result != simd_result:
        print("ERROR: scalar and SIMD results differ")
        return

    var scalar_start = perf_counter_ns()
    for _ in range(iterations):
        _ = count_term_scalar(data, term)
    var scalar_ns = perf_counter_ns() - scalar_start

    var simd_start = perf_counter_ns()
    for _ in range(iterations):
        _ = count_term_simd(data, term)
    var simd_ns = perf_counter_ns() - simd_start

    print("bytes:", len(data))
    print("matches:", simd_result)
    print("iterations:", iterations)
    print("scalar total ns:", scalar_ns)
    print("SIMD total ns:", simd_ns)


def main() raises:
    var args = argv()
    if len(args) < 3:
        print("Usage: mojo run src/analyzer.mojo <file> <term> [iterations]")
        return

    var iterations = 100
    if len(args) > 3:
        iterations = atol(args[3])

    with open(args[1], "r") as file:
        var data = file.read_bytes()
        var term = String(args[2]).as_bytes()
        benchmark(Span(data), term, iterations)
