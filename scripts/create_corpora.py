from pathlib import Path

SOURCE = Path("data/sample.txt")

CORPORA = {
    "data/research-10mb.txt": 10 * 1024 * 1024,
    "data/research-100mb.txt": 100 * 1024 * 1024,
}


def create_corpus(output_path: str, minimum_size: int) -> None:
    source = SOURCE.read_bytes()

    if not source:
        raise ValueError("data/sample.txt is empty")

    separator = b"\n\n"
    output = Path(output_path)

    with output.open("wb") as destination:
        while destination.tell() < minimum_size:
            destination.write(source)
            destination.write(separator)

    print(f"{output}: {output.stat().st_size:,} bytes")


def main() -> None:
    for output_path, minimum_size in CORPORA.items():
        create_corpus(output_path, minimum_size)


if __name__ == "__main__":
    main()