basepath = "http://ftp.vim.org/pub/vim/runtime/spell/"
spell_home = "~/.config/nvim/spell/"

--[
-- Checks if a file or directory exists.
-- ]
function exists(path)
  local file = os.execute("test -f "..path)
  local dir = os.execute("test -d "..path)
  return (dir or file) == true
end

--[
-- Downloads a specific language file from the vim servers.
-- @Asserts correct lang, spell_home, basepath and internett connection.
--]
function download(url, dest)
  if exists(spell_home..lang) then
    print("file exists")
  else
    if not io.popen("which curl &> /dev/null") then
      print("curl not found")
    else 
      if not exists(spell_home) then
        io.popen("mkdir "..spell_home)
      end
      local URL = "curl -o "..dest.." "..url.." -s --fail"
      local result = os.execute(URL)
      if result then
       print("download failed") 
      end
    end
  end
end

--[ just to test it
--lang = "he.utf-8.spl"
--dest = spell_home..lang2
--url= basepath..lang2
--download(url,dest)
--]
