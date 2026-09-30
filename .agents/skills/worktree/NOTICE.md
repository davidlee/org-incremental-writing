# NOTICE — /worktree skill attribution

The directory-selection and safety-verification patterns in `SKILL.md` (the
existing-directory priority, the `CLAUDE.md` preference check, the `git
check-ignore` safety gate, and the "fix broken things immediately" framing) are
adapted from **`superpowers:using-git-worktrees`** by **Jesse Vincent**
(<https://github.com/obra/superpowers>), licensed MIT.

Doctrine replaces that skill's project-setup auto-detect with `doctrine worktree
provision` (the sole copier, coordination-tier exclusion at the copy seam) and adds
the detection step, the creation backend ladder, the `mode = solo | worker`
contract, and the commit-before-spawn / branch-point / baseline guards.

```
MIT License — Copyright (c) 2025 Jesse Vincent

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in the
Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
