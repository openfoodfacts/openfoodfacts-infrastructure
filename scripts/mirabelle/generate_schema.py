import csv
import re
import sys

def load_known_types(schema_file):
    """
    Read previous schema and extract column -> type.
    Lines look like: [field_name] TEXT,
    """
    known = {}
    col_re = re.compile(r"\[(.+?)\]\s+([A-Z]+)")
    with open(schema_file, encoding="utf-8") as f:
        for line in f:
            m = col_re.search(line)
            if m:
                col, coltype = m.groups()
                known[col] = coltype
    return known

def guess_type(values):
    """Infer SQLite type unless overridden by known types."""
    has_float = False

    for v in values:
        if v == "":
            continue
        # integer?
        if v.isdigit() or (v.startswith("-") and v[1:].isdigit()):
            continue
        # float?
        try:
            float(v)
            has_float = True
            continue
        except ValueError:
            return "TEXT"

    return "REAL" if has_float else "INTEGER"

def generate_schema(csv_file, old_schema_file, table_name="all"):
    known_types = load_known_types(old_schema_file)

    with open(csv_file, encoding="utf-8") as f:
        reader = csv.reader(f, delimiter="\t")

        headers = next(reader)
        sample = {h: [] for h in headers}

        # Gather a sample
        for i, row in enumerate(reader):
            for h, v in zip(headers, row):
                sample[h].append(v)
            if i > 20000:
                break

    # Build schema
    lines = []
    for h in headers:
        if h in known_types:
            coltype = known_types[h]     # ⬅ trusted type
        else:
            coltype = guess_type(sample[h])
        lines.append(f'   [{h}] {coltype}')

    return "CREATE TABLE IF NOT EXISTS \"{}\" (\n{}\n);".format(
        table_name,
        ",\n".join(lines)
    )

if __name__ == "__main__":
    csv_file = sys.argv[1]
    schema_file = sys.argv[2]
    print(generate_schema(csv_file, schema_file))

