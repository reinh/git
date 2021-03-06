#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='Test commit notes'

. ./test-lib.sh

cat > fake_editor.sh << \EOF
#!/bin/sh
echo "$MSG" > "$1"
echo "$MSG" >& 2
EOF
chmod a+x fake_editor.sh
GIT_EDITOR=./fake_editor.sh
export GIT_EDITOR

test_expect_success 'cannot annotate non-existing HEAD' '
	(MSG=3 && export MSG && test_must_fail git notes add)
'

test_expect_success setup '
	: > a1 &&
	git add a1 &&
	test_tick &&
	git commit -m 1st &&
	: > a2 &&
	git add a2 &&
	test_tick &&
	git commit -m 2nd
'

test_expect_success 'need valid notes ref' '
	(MSG=1 GIT_NOTES_REF=/ && export MSG GIT_NOTES_REF &&
	 test_must_fail git notes add) &&
	(MSG=2 GIT_NOTES_REF=/ && export MSG GIT_NOTES_REF &&
	 test_must_fail git notes show)
'

test_expect_success 'refusing to add notes in refs/heads/' '
	(MSG=1 GIT_NOTES_REF=refs/heads/bogus &&
	 export MSG GIT_NOTES_REF &&
	 test_must_fail git notes add)
'

test_expect_success 'refusing to edit notes in refs/remotes/' '
	(MSG=1 GIT_NOTES_REF=refs/remotes/bogus &&
	 export MSG GIT_NOTES_REF &&
	 test_must_fail git notes edit)
'

# 1 indicates caught gracefully by die, 128 means git-show barked
test_expect_success 'handle empty notes gracefully' '
	git notes show ; test 1 = $?
'

test_expect_success 'create notes' '
	git config core.notesRef refs/notes/commits &&
	MSG=b4 git notes add &&
	test ! -f .git/NOTES_EDITMSG &&
	test 1 = $(git ls-tree refs/notes/commits | wc -l) &&
	test b4 = $(git notes show) &&
	git show HEAD^ &&
	test_must_fail git notes show HEAD^
'

test_expect_success 'edit existing notes' '
	MSG=b3 git notes edit &&
	test ! -f .git/NOTES_EDITMSG &&
	test 1 = $(git ls-tree refs/notes/commits | wc -l) &&
	test b3 = $(git notes show) &&
	git show HEAD^ &&
	test_must_fail git notes show HEAD^
'

test_expect_success 'cannot add note where one exists' '
	! MSG=b2 git notes add &&
	test ! -f .git/NOTES_EDITMSG &&
	test 1 = $(git ls-tree refs/notes/commits | wc -l) &&
	test b3 = $(git notes show) &&
	git show HEAD^ &&
	test_must_fail git notes show HEAD^
'

test_expect_success 'can overwrite existing note with "git notes add -f"' '
	MSG=b1 git notes add -f &&
	test ! -f .git/NOTES_EDITMSG &&
	test 1 = $(git ls-tree refs/notes/commits | wc -l) &&
	test b1 = $(git notes show) &&
	git show HEAD^ &&
	test_must_fail git notes show HEAD^
'

cat > expect << EOF
commit 268048bfb8a1fb38e703baceb8ab235421bf80c5
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:14:13 2005 -0700

    2nd

Notes:
    b1
EOF

test_expect_success 'show notes' '
	! (git cat-file commit HEAD | grep b1) &&
	git log -1 > output &&
	test_cmp expect output
'

test_expect_success 'create multi-line notes (setup)' '
	: > a3 &&
	git add a3 &&
	test_tick &&
	git commit -m 3rd &&
	MSG="b3
c3c3c3c3
d3d3d3" git notes add
'

cat > expect-multiline << EOF
commit 1584215f1d29c65e99c6c6848626553fdd07fd75
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:15:13 2005 -0700

    3rd

Notes:
    b3
    c3c3c3c3
    d3d3d3
EOF

printf "\n" >> expect-multiline
cat expect >> expect-multiline

test_expect_success 'show multi-line notes' '
	git log -2 > output &&
	test_cmp expect-multiline output
'
test_expect_success 'create -F notes (setup)' '
	: > a4 &&
	git add a4 &&
	test_tick &&
	git commit -m 4th &&
	echo "xyzzy" > note5 &&
	git notes add -F note5
'

cat > expect-F << EOF
commit 15023535574ded8b1a89052b32673f84cf9582b8
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:16:13 2005 -0700

    4th

Notes:
    xyzzy
EOF

printf "\n" >> expect-F
cat expect-multiline >> expect-F

test_expect_success 'show -F notes' '
	git log -3 > output &&
	test_cmp expect-F output
'

cat >expect << EOF
commit 15023535574ded8b1a89052b32673f84cf9582b8
tree e070e3af51011e47b183c33adf9736736a525709
parent 1584215f1d29c65e99c6c6848626553fdd07fd75
author A U Thor <author@example.com> 1112912173 -0700
committer C O Mitter <committer@example.com> 1112912173 -0700

    4th
EOF
test_expect_success 'git log --pretty=raw does not show notes' '
	git log -1 --pretty=raw >output &&
	test_cmp expect output
'

cat >>expect <<EOF

Notes:
    xyzzy
EOF
test_expect_success 'git log --show-notes' '
	git log -1 --pretty=raw --show-notes >output &&
	test_cmp expect output
'

test_expect_success 'git log --no-notes' '
	git log -1 --no-notes >output &&
	! grep xyzzy output
'

test_expect_success 'git format-patch does not show notes' '
	git format-patch -1 --stdout >output &&
	! grep xyzzy output
'

test_expect_success 'git format-patch --show-notes does show notes' '
	git format-patch --show-notes -1 --stdout >output &&
	grep xyzzy output
'

for pretty in \
	"" --pretty --pretty=raw --pretty=short --pretty=medium \
	--pretty=full --pretty=fuller --pretty=format:%s --oneline
do
	case "$pretty" in
	"") p= not= negate="" ;;
	?*) p="$pretty" not=" not" negate="!" ;;
	esac
	test_expect_success "git show $pretty does$not show notes" '
		git show $p >output &&
		eval "$negate grep xyzzy output"
	'
done

test_expect_success 'create -m notes (setup)' '
	: > a5 &&
	git add a5 &&
	test_tick &&
	git commit -m 5th &&
	git notes add -m spam -m "foo
bar
baz"
'

whitespace="    "
cat > expect-m << EOF
commit bd1753200303d0a0344be813e504253b3d98e74d
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:17:13 2005 -0700

    5th

Notes:
    spam
$whitespace
    foo
    bar
    baz
EOF

printf "\n" >> expect-m
cat expect-F >> expect-m

test_expect_success 'show -m notes' '
	git log -4 > output &&
	test_cmp expect-m output
'

test_expect_success 'remove note with add -f -F /dev/null (setup)' '
	git notes add -f -F /dev/null
'

cat > expect-rm-F << EOF
commit bd1753200303d0a0344be813e504253b3d98e74d
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:17:13 2005 -0700

    5th
EOF

printf "\n" >> expect-rm-F
cat expect-F >> expect-rm-F

test_expect_success 'verify note removal with -F /dev/null' '
	git log -4 > output &&
	test_cmp expect-rm-F output &&
	! git notes show
'

test_expect_success 'do not create empty note with -m "" (setup)' '
	git notes add -m ""
'

test_expect_success 'verify non-creation of note with -m ""' '
	git log -4 > output &&
	test_cmp expect-rm-F output &&
	! git notes show
'

cat > expect-combine_m_and_F << EOF
foo

xyzzy

bar

zyxxy

baz
EOF

test_expect_success 'create note with combination of -m and -F' '
	echo "xyzzy" > note_a &&
	echo "zyxxy" > note_b &&
	git notes add -m "foo" -F note_a -m "bar" -F note_b -m "baz" &&
	git notes show > output &&
	test_cmp expect-combine_m_and_F output
'

test_expect_success 'remove note with "git notes remove" (setup)' '
	git notes remove HEAD^ &&
	git notes remove
'

cat > expect-rm-remove << EOF
commit bd1753200303d0a0344be813e504253b3d98e74d
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:17:13 2005 -0700

    5th

commit 15023535574ded8b1a89052b32673f84cf9582b8
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:16:13 2005 -0700

    4th
EOF

printf "\n" >> expect-rm-remove
cat expect-multiline >> expect-rm-remove

test_expect_success 'verify note removal with "git notes remove"' '
	git log -4 > output &&
	test_cmp expect-rm-remove output &&
	! git notes show HEAD^
'

cat > expect << EOF
c18dc024e14f08d18d14eea0d747ff692d66d6a3 1584215f1d29c65e99c6c6848626553fdd07fd75
c9c6af7f78bc47490dbf3e822cf2f3c24d4b9061 268048bfb8a1fb38e703baceb8ab235421bf80c5
EOF

test_expect_success 'list notes with "git notes list"' '
	git notes list > output &&
	test_cmp expect output
'

test_expect_success 'list notes with "git notes"' '
	git notes > output &&
	test_cmp expect output
'

cat > expect << EOF
c18dc024e14f08d18d14eea0d747ff692d66d6a3
EOF

test_expect_success 'list specific note with "git notes list <object>"' '
	git notes list HEAD^^ > output &&
	test_cmp expect output
'

cat > expect << EOF
EOF

test_expect_success 'listing non-existing notes fails' '
	test_must_fail git notes list HEAD > output &&
	test_cmp expect output
'

cat > expect << EOF
Initial set of notes

More notes appended with git notes append
EOF

test_expect_success 'append to existing note with "git notes append"' '
	git notes add -m "Initial set of notes" &&
	git notes append -m "More notes appended with git notes append" &&
	git notes show > output &&
	test_cmp expect output
'

test_expect_success 'appending empty string does not change existing note' '
	git notes append -m "" &&
	git notes show > output &&
	test_cmp expect output
'

test_expect_success 'git notes append == add when there is no existing note' '
	git notes remove HEAD &&
	test_must_fail git notes list HEAD &&
	git notes append -m "Initial set of notes

More notes appended with git notes append" &&
	git notes show > output &&
	test_cmp expect output
'

test_expect_success 'appending empty string to non-existing note does not create note' '
	git notes remove HEAD &&
	test_must_fail git notes list HEAD &&
	git notes append -m "" &&
	test_must_fail git notes list HEAD
'

test_expect_success 'create other note on a different notes ref (setup)' '
	: > a6 &&
	git add a6 &&
	test_tick &&
	git commit -m 6th &&
	GIT_NOTES_REF="refs/notes/other" git notes add -m "other note"
'

cat > expect-other << EOF
commit 387a89921c73d7ed72cd94d179c1c7048ca47756
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:18:13 2005 -0700

    6th

Notes:
    other note
EOF

cat > expect-not-other << EOF
commit 387a89921c73d7ed72cd94d179c1c7048ca47756
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:18:13 2005 -0700

    6th
EOF

test_expect_success 'Do not show note on other ref by default' '
	git log -1 > output &&
	test_cmp expect-not-other output
'

test_expect_success 'Do show note when ref is given in GIT_NOTES_REF' '
	GIT_NOTES_REF="refs/notes/other" git log -1 > output &&
	test_cmp expect-other output
'

test_expect_success 'Do show note when ref is given in core.notesRef config' '
	git config core.notesRef "refs/notes/other" &&
	git log -1 > output &&
	test_cmp expect-other output
'

test_expect_success 'Do not show note when core.notesRef is overridden' '
	GIT_NOTES_REF="refs/notes/wrong" git log -1 > output &&
	test_cmp expect-not-other output
'

test_expect_success 'Allow notes on non-commits (trees, blobs, tags)' '
	echo "Note on a tree" > expect
	git notes add -m "Note on a tree" HEAD: &&
	git notes show HEAD: > actual &&
	test_cmp expect actual &&
	echo "Note on a blob" > expect
	filename=$(git ls-tree --name-only HEAD | head -n1) &&
	git notes add -m "Note on a blob" HEAD:$filename &&
	git notes show HEAD:$filename > actual &&
	test_cmp expect actual &&
	echo "Note on a tag" > expect
	git tag -a -m "This is an annotated tag" foobar HEAD^ &&
	git notes add -m "Note on a tag" foobar &&
	git notes show foobar > actual &&
	test_cmp expect actual
'

cat > expect << EOF
commit 2ede89468182a62d0bde2583c736089bcf7d7e92
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:19:13 2005 -0700

    7th

Notes:
    other note
EOF

test_expect_success 'create note from other note with "git notes add -C"' '
	: > a7 &&
	git add a7 &&
	test_tick &&
	git commit -m 7th &&
	git notes add -C $(git notes list HEAD^) &&
	git log -1 > actual &&
	test_cmp expect actual &&
	test "$(git notes list HEAD)" = "$(git notes list HEAD^)"
'

test_expect_success 'create note from non-existing note with "git notes add -C" fails' '
	: > a8 &&
	git add a8 &&
	test_tick &&
	git commit -m 8th &&
	test_must_fail git notes add -C deadbeef &&
	test_must_fail git notes list HEAD
'

cat > expect << EOF
commit 016e982bad97eacdbda0fcbd7ce5b0ba87c81f1b
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:21:13 2005 -0700

    9th

Notes:
    yet another note
EOF

test_expect_success 'create note from other note with "git notes add -c"' '
	: > a9 &&
	git add a9 &&
	test_tick &&
	git commit -m 9th &&
	MSG="yet another note" git notes add -c $(git notes list HEAD^^) &&
	git log -1 > actual &&
	test_cmp expect actual
'

test_expect_success 'create note from non-existing note with "git notes add -c" fails' '
	: > a10 &&
	git add a10 &&
	test_tick &&
	git commit -m 10th &&
	test_must_fail MSG="yet another note" git notes add -c deadbeef &&
	test_must_fail git notes list HEAD
'

cat > expect << EOF
commit 016e982bad97eacdbda0fcbd7ce5b0ba87c81f1b
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:21:13 2005 -0700

    9th

Notes:
    yet another note
$whitespace
    yet another note
EOF

test_expect_success 'append to note from other note with "git notes append -C"' '
	git notes append -C $(git notes list HEAD^) HEAD^ &&
	git log -1 HEAD^ > actual &&
	test_cmp expect actual
'

cat > expect << EOF
commit ffed603236bfa3891c49644257a83598afe8ae5a
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:22:13 2005 -0700

    10th

Notes:
    other note
EOF

test_expect_success 'create note from other note with "git notes append -c"' '
	MSG="other note" git notes append -c $(git notes list HEAD^) &&
	git log -1 > actual &&
	test_cmp expect actual
'

cat > expect << EOF
commit ffed603236bfa3891c49644257a83598afe8ae5a
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:22:13 2005 -0700

    10th

Notes:
    other note
$whitespace
    yet another note
EOF

test_expect_success 'append to note from other note with "git notes append -c"' '
	MSG="yet another note" git notes append -c $(git notes list HEAD) &&
	git log -1 > actual &&
	test_cmp expect actual
'

cat > expect << EOF
commit 6352c5e33dbcab725fe0579be16aa2ba8eb369be
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:23:13 2005 -0700

    11th

Notes:
    other note
$whitespace
    yet another note
EOF

test_expect_success 'copy note with "git notes copy"' '
	: > a11 &&
	git add a11 &&
	test_tick &&
	git commit -m 11th &&
	git notes copy HEAD^ HEAD &&
	git log -1 > actual &&
	test_cmp expect actual &&
	test "$(git notes list HEAD)" = "$(git notes list HEAD^)"
'

test_expect_success 'prevent overwrite with "git notes copy"' '
	test_must_fail git notes copy HEAD~2 HEAD &&
	git log -1 > actual &&
	test_cmp expect actual &&
	test "$(git notes list HEAD)" = "$(git notes list HEAD^)"
'

cat > expect << EOF
commit 6352c5e33dbcab725fe0579be16aa2ba8eb369be
Author: A U Thor <author@example.com>
Date:   Thu Apr 7 15:23:13 2005 -0700

    11th

Notes:
    yet another note
$whitespace
    yet another note
EOF

test_expect_success 'allow overwrite with "git notes copy -f"' '
	git notes copy -f HEAD~2 HEAD &&
	git log -1 > actual &&
	test_cmp expect actual &&
	test "$(git notes list HEAD)" = "$(git notes list HEAD~2)"
'

test_expect_success 'cannot copy note from object without notes' '
	: > a12 &&
	git add a12 &&
	test_tick &&
	git commit -m 12th &&
	: > a13 &&
	git add a13 &&
	test_tick &&
	git commit -m 13th &&
	test_must_fail git notes copy HEAD^ HEAD
'

test_done
