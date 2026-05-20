# Copyright 2025 OneSix Solutions
# SPDX-License-Identifier: Apache-2.0
#
# Walks the repository and prepends Apache 2.0 license headers to .py, .sql,
# and .yml files that don't already contain the SPDX identifier.
# Skips target/, dbt_packages/, and .git/ directories.

import os

SPDX_IDENTIFIER = "SPDX-License-Identifier: Apache-2.0"

HEADER_SQL = """\
-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

"""

HEADER_YAML = """\
# Copyright 2025 OneSix Solutions
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""

HEADER_PY = HEADER_YAML

SKIP_DIRS = {".git", "target", "dbt_packages", "__pycache__", ".venv", "venv"}

EXTENSION_MAP = {
    ".sql": HEADER_SQL,
    ".yml": HEADER_YAML,
    ".yaml": HEADER_YAML,
    ".py": HEADER_PY,
}


def apply_headers(root_dir: str) -> None:
    processed = updated = skipped = 0

    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]

        for filename in filenames:
            ext = os.path.splitext(filename)[1].lower()
            header = EXTENSION_MAP.get(ext)
            if not header:
                continue

            filepath = os.path.join(dirpath, filename)

            # Skip this script itself
            if os.path.abspath(filepath) == os.path.abspath(__file__):
                skipped += 1
                continue

            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except (UnicodeDecodeError, OSError):
                skipped += 1
                continue

            processed += 1

            if SPDX_IDENTIFIER in content:
                skipped += 1
                continue

            with open(filepath, "w", encoding="utf-8") as f:
                f.write(header + content)

            updated += 1
            print(f"  Updated: {filepath}")

    print(f"\nDone. Processed: {processed}  Updated: {updated}  Skipped: {skipped}")


if __name__ == "__main__":
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"Applying license headers under: {repo_root}\n")
    apply_headers(repo_root)
