The linter used in this project is shellcheck, with no globally disabled
features for now.

In addition to this, what follows are some additional lint-sanity checks.
These are not perfect, but serve as a starting point.

```bash
find . | entr -c git grep -n EXCEPTION_BAD_FN_CALL
```

```bash
find . | entr -c git grep -nE '(local -i|let) [a-zA-Z0-9_]+=\$\{'
$ sed -i.junk -E -e 's/local -i ([_a-zA-Z0-9]+)=(\$[\(\{].+)$/local -i \1; let \1=\2/g' bin/simbol module/*.sh lib/libsh/libsimbol/*.sh share/unit/tests/*.sh
```

```bash
find . | entr -c git grep -B1 "let e=\$\{"
$ sed -E -i .junk -e 's/let e=\$\{(CODE_[A-Z]+)\??\}/let e=\1/g' module/*.sh lib/libsh/libsimbol/*.sh share/unit/tests/*.sh
```

Shellcheck - Issues By-File Summary
```bash
shellcheck -x -s bash module/*.sh bin/* share/unit/citm share/unit/shunit2parent.sh share/unit/tests/*.sh
shellcheck -x -s bash module/*.sh bin/* share/unit/citm share/unit/shunit2parent.sh share/unit/tests/*.sh|awk '$1~/^In/{print$2}'|uniq -c|sort -n
```

Shellcheck - Issues By-Code Summary
```bash
shellcheck -x -s bash module/*.sh bin/* share/unit/citm share/unit/shunit2parent.sh share/unit/tests/*.sh|grep -oE '\SC[0-9]{4}'|sort|uniq -c|sort -n
```
