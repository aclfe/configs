#!/usr/bin/env bash
set -euo pipefail

git worktree add -d wt-base 47caaaab0b
git worktree add -d wt-head df028f6756
(cd wt-base && ./mvnw -q -Passembly,no-validations -DskipTests package)
(cd wt-head && ./mvnw -q -Passembly,no-validations -DskipTests package)

cat > bench-config.xml <<'XML'
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">
<module name="Checker">
  <module name="SuppressWithPlainTextCommentFilter"/>
  <module name="LineLength">
    <property name="max" value="20"/>
  </module>
</module>
XML

find wt-base/src -name '*.java' | sort > corpus.txt
mapfile -t FILES < corpus.txt
echo "files: ${#FILES[@]}"

java -Xmx1024m -jar wt-base/target/checkstyle-14.2.0-SNAPSHOT-all.jar -c bench-config.xml "${FILES[@]}" > out-base.txt || true
java -Xmx1024m -jar wt-head/target/checkstyle-14.2.0-SNAPSHOT-all.jar -c bench-config.xml "${FILES[@]}" > out-head.txt || true
diff -q out-base.txt out-head.txt && echo "outputs identical"

for i in 1 2 3 4 5; do
  for side in base head; do
    /usr/bin/time -v java -Xmx1024m -jar wt-$side/target/checkstyle-14.2.0-SNAPSHOT-all.jar \
        -c bench-config.xml "${FILES[@]}" > /dev/null 2> time-$side-$i.txt || true
    printf '%s run %d: ' "$side" "$i"
    grep -E 'Elapsed \(wall|Maximum resident' time-$side-$i.txt | awk -F': ' '{printf "%s  ", $2}'
    echo
  done
done
