#!/usr/bin/env bash
# Еталон: версія фіксується явно через dependencyManagement (або exclusion для зайвої гілки).
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
P="$WORKDIR/06/pom.xml"
python3 - "$P" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
dm = '''  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>com.google.guava</groupId>
        <artifactId>guava</artifactId>
        <version>32.1.3-jre</version>
      </dependency>
    </dependencies>
  </dependencyManagement>
'''
if "<dependencyManagement>" not in text:
    text = text.replace("  <dependencies>", dm + "  <dependencies>", 1)
p.write_text(text, encoding="utf-8")
print("   еталон: версію guava зафіксовано через dependencyManagement")
PY
