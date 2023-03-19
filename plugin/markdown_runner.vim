if exists("g:loaded_markdown_runner")
  finish
endif

command! MarkdownRunner lua require("markdown_runner").echo()
command! MarkdownRunnerInsert lua require("markdown_runner").insert()
command! MarkdownRunnerClearCache lua require("markdown_runner").clear_cache()
command! -nargs=1 MarkdownCollect lua require("markdown_runner.collect").collect(<f-args>)

let g:loaded_markdown_runner = 1
