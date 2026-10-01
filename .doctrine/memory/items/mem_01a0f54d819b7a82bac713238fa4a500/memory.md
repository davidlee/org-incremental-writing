On Emacs 30.2 and 31.1, `basic-save-buffer` demotes errors raised by
`before-save-hook`: the save still succeeds. To make a save fail in a test,
signal from `write-file-functions` (or `write-contents-functions`), or make
`write-region` fail (file modes). Found in SL-001 PHASE-05; design §5.2/§9
and plan PHASE-05 VT-3 were written assuming the hook could fail the save.
