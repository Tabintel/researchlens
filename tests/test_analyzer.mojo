from std.testing import assert_equal

# The Pixi task adds src/ to Mojo's module search path.
from analyzer import count_term_scalar, count_term_simd


def check(text: String, term: String, expected: Int) raises:
    var data = text.as_bytes()
    var needle = term.as_bytes()

    assert_equal(count_term_scalar(data, needle), expected)
    assert_equal(count_term_simd(data, needle), expected)


def main() raises:
    check("", "research", 0)
    check("research", "research", 1)
    check("research research", "research", 2)
    check("researcher research", "research", 1)
    check(
        "A long prefix that crosses a vector tail: research",
        "research",
        1,
    )

    print("ResearchLens: all scalar/SIMD agreement tests passed")