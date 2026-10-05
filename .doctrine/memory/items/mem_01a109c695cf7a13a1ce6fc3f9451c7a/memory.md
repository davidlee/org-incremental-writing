`org-entry-delete` matches the property key case-sensitively unless
`case-fold-search` is non-nil, so `:iw_q:` survives a delete of `IW_Q`.
`org-iw-write-delete-rank` binds `case-fold-search` to t (SL-003 research
fact 3; tested by the lowercase-key delete case).
