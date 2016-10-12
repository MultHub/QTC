local version = 1
local latest = 0
local balance = 0
local MOD = 2^32
local MODM = MOD-1
local gui = 0
local page = 0
local lastpage = 0
local scroll = 0
local masterkey = ""
local addressv1 = ""
local address = ""
local subject = ""
local subbal = 0
local subtxs = ""
local stdate = {}
local stpeer = {}
local stval = {}
local blkpeer = {}
local pagespace = ""
local maxspace = ""
local ar = 0
local function boot()
  print("Starting QuantumTechCoinWallet v"..tostring(version))
  update()
  if latest == version then
    settle()
    openwallet()
    repeat
      wallet()
    until page == 0
    term.setBackgroundColor(32768)
    term.setTextColor(16)
    term.clear()
    term.setCursorPos(1,1)
  end
end
function update()
  latest = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getwalletversion").readAll())
  if latest > version then
    print("An update is available!")
    local me = fs.open(fs.getName(shell.getRunningProgram()),"w")
    local nextversion = http.get("http://coinserv.ceriat.net/c/qtc/qtcwallet.lua").readAll()
    print("Installed update. Run this program again to start v"..latest..".")
    me.write(nextversion)
    me.close()
  else
    --print("Up to date!")
    --print("Version "..tostring(version))
  end  
end
function settle()
  if term.isColor() then gui = 1 end
  if term.isColor() and pocket then gui = 2 end
end
local function drawQuantumTechCoin()
  posx, posy = term.getCursorPos()
  term.setBackgroundColor(1)
  term.setTextColor(colors.lightGray)
  term.write("/")
  term.setBackgroundColor(colors.lightGray)
  term.setTextColor(colors.gray)
  term.write("\\")
  term.setCursorPos(posx,posy+1)
  term.setBackgroundColor(colors.lightGray)
  term.setTextColor(colors.gray)
  term.write("\\")
  term.setBackgroundColor(colors.gray)
  term.setTextColor(colors.lightGray)
  term.write("/")
  term.setCursorPos(posx+2,posy)
end
local function memoize(f)
        local mt = {}
        local t = setmetatable({}, mt)
        function mt:__index(k)
                local v = f(k)
                t[k] = v
                return v
        end
        return t
end
local function make_bitop_uncached(t, m)
        local function bitop(a, b)
                local res,p = 0,1
                while a ~= 0 and b ~= 0 do
                        local am, bm = a % m, b % m
                        res = res + t[am][bm] * p
                        a = (a - am) / m
                        b = (b - bm) / m
                        p = p*m
                end
                res = res + (a + b) * p
                return res
        end
        return bitop
end
local function make_bitop(t)
        local op1 = make_bitop_uncached(t,2^1)
        local op2 = memoize(function(a) return memoize(function(b) return op1(a, b) end) end)
        return make_bitop_uncached(op2, 2 ^ (t.n or 1))
end
local bxor1 = make_bitop({[0] = {[0] = 0,[1] = 1}, [1] = {[0] = 1, [1] = 0}, n = 4})
local function bxor(a, b, c, ...)
        local z = nil
        if b then
                a = a % MOD
                b = b % MOD
                z = bxor1(a, b)
                if c then z = bxor(z, c, ...) end
                return z
        elseif a then return a % MOD
        else return 0 end
end
local function band(a, b, c, ...)
        local z
        if b then
                a = a % MOD
                b = b % MOD
                z = ((a + b) - bxor1(a,b)) / 2
                if c then z = bit32_band(z, c, ...) end
                return z
        elseif a then return a % MOD
        else return MODM end
end
local function bnot(x) return (-1 - x) % MOD end
local function rshift1(a, disp)
        if disp < 0 then return lshift(a,-disp) end
        return math.floor(a % 2 ^ 32 / 2 ^ disp)
end
local function rshift(x, disp)
        if disp > 31 or disp < -31 then return 0 end
        return rshift1(x % MOD, disp)
end
local function lshift(a, disp)
        if disp < 0 then return rshift(a,-disp) end
        return (a * 2 ^ disp) % 2 ^ 32
end
local function rrotate(x, disp)
    x = x % MOD
    disp = disp % 32
    local low = band(x, 2 ^ disp - 1)
    return rshift(x, disp) + lshift(low, 32 - disp)
end
local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local function str2hexa(s)
        return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
end
local function num2s(l, n)
        local s = ""
        for i = 1, n do
                local rem = l % 256
                s = string.char(rem) .. s
                l = (l - rem) / 256
        end
        return s
end
local function s232num(s, i)
        local n = 0
        for i = i, i + 3 do n = n*256 + string.byte(s, i) end
        return n
end
local function preproc(msg, len)
        local extra = 64 - ((len + 9) % 64)
        len = num2s(8 * len, 8)
        msg = msg .. "\128" .. string.rep("\0", extra) .. len
        assert(#msg % 64 == 0)
        return msg
end
local function initH256(H)
        H[1] = 0x6a09e667
        H[2] = 0xbb67ae85
        H[3] = 0x3c6ef372
        H[4] = 0xa54ff53a
        H[5] = 0x510e527f
        H[6] = 0x9b05688c
        H[7] = 0x1f83d9ab
        H[8] = 0x5be0cd19
        return H
end
local function digestblock(msg, i, H)
        local w = {}
        for j = 1, 16 do w[j] = s232num(msg, i + (j - 1)*4) end
        for j = 17, 64 do
                local v = w[j - 15]
                local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
                v = w[j - 2]
                w[j] = w[j - 16] + s0 + w[j - 7] + bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
        end
 
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for i = 1, 64 do
                local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
                local maj = bxor(band(a, b), band(a, c), band(b, c))
                local t2 = s0 + maj
                local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
                local ch = bxor (band(e, f), band(bnot(e), g))
                local t1 = h + s1 + ch + k[i] + w[i]
                h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
        end
 
        H[1] = band(H[1] + a)
        H[2] = band(H[2] + b)
        H[3] = band(H[3] + c)
        H[4] = band(H[4] + d)
        H[5] = band(H[5] + e)
        H[6] = band(H[6] + f)
        H[7] = band(H[7] + g)
        H[8] = band(H[8] + h)
end
local function sha256(msg)
        msg = preproc(msg, #msg)
        local H = initH256({})
        for i = 1, #msg, 64 do digestblock(msg, i, H) end
        return str2hexa(num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
                num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4))
end
local function hextobase36(j)
  if j <= 6 then return "0"
  elseif j <= 13 then return "1"
  elseif j <= 20 then return "2"
  elseif j <= 27 then return "3"
  elseif j <= 34 then return "4"
  elseif j <= 41 then return "5"
  elseif j <= 48 then return "6"
  elseif j <= 55 then return "7"
  elseif j <= 62 then return "8"
  elseif j <= 69 then return "9"
  elseif j <= 76 then return "a"
  elseif j <= 83 then return "b"
  elseif j <= 90 then return "c"
  elseif j <= 97 then return "d"
  elseif j <= 104 then return "e"
  elseif j <= 111 then return "f"
  elseif j <= 118 then return "g"
  elseif j <= 125 then return "h"
  elseif j <= 132 then return "i"
  elseif j <= 139 then return "j"
  elseif j <= 146 then return "k"
  elseif j <= 153 then return "l"
  elseif j <= 160 then return "m"
  elseif j <= 167 then return "n"
  elseif j <= 174 then return "o"
  elseif j <= 181 then return "p"
  elseif j <= 188 then return "q"
  elseif j <= 195 then return "r"
  elseif j <= 202 then return "s"
  elseif j <= 209 then return "t"
  elseif j <= 216 then return "u"
  elseif j <= 223 then return "v"
  elseif j <= 230 then return "w"
  elseif j <= 237 then return "x"
  elseif j <= 244 then return "y"
  elseif j <= 251 then return "z"
  else return "e"
  end
end
function openwallet()
  term.setBackgroundColor(8)
  term.clear()
  local krists = 0
  repeat
    term.setCursorPos(3+(3*krists),3)
    drawQuantumTechCoin()
    krists = krists + 1
  until krists == 16
  krists = 0
  repeat
    term.setCursorPos(3+(3*krists),16)
    drawQuantumTechCoin()
    krists = krists + 1
  until krists == 16
  term.setBackgroundColor(8)
  term.setTextColor(32768)
  term.setCursorPos(6,6)
  term.write("Password:")
  term.setCursorPos(6,8)
         -----|---+---------+---------+---------+-----|---+-
  term.write("Please enter your password.")--[[
  term.setCursorPos(6,9)
  term.write("use QuantumTechCoin. If this is your first time")
  term.setCursorPos(6,10)
  term.write("using QuantumTechCoin, type your desired password.")
  term.setCursorPos(6,11)
  term.write("You will be able to access your QuantumTechCoin")
  term.setCursorPos(6,12)
  term.write("on any computer on any server as long")
  term.setCursorPos(6,13)
  term.write("as you type in the same password! It will")
  term.setCursorPos(6,14)
  term.write("not be saved or shared with anyone.")]]
  term.setCursorPos(16,6)
  local password = read("*")
  password = sha256("KRISTWALLET"..password)
  term.clear()
  term.setCursorPos(1,1)
  page = 1+gui*(10*(gui-1))
  masterkey = password.."-000"
  addressv1 = string.sub(sha256(masterkey),0,10)
  local protein = {}
  local stick = sha256(sha256(masterkey))
  local n = 0
  local link = 0
  repeat
    if n < 9 then protein[n] = string.sub(stick,0,2)
    stick = sha256(sha256(stick)) end
    n = n + 1
  until n == 9
  address = 'q'
  n = 0
  repeat
    link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
    if string.len(protein[link]) ~= 0 then
      address = address .. hextobase36(tonumber(protein[link],16))
      protein[link] = ''
      n = n + 1
    else
      stick = sha256(stick)
    end
  until n == 9
  balance = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..addressv1).readAll())
  if balance > 0 then local transaction = http.get("http://coinserv.ceriat.net/c/qtc/index.php?pushtx&q="..address.."&pkey="..masterkey.."&amt="..balance).readAll() end
  balance = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..address).readAll())
end
local function postgraphic(px,py,id)
  term.setCursorPos(px,py)
  if id == 0 then drawQuantumTechCoin()
  elseif id == 1 then
    --Mined QuantumTechCoin
    term.setCursorPos(px+1,py)
    term.setBackgroundColor(256)
    term.setTextColor(128)
    term.write("/T\\")
    term.setCursorPos(px,py+1)
    term.write("/")
    term.setCursorPos(px+2,py+1)
    term.write("|")
    term.setCursorPos(px+4,py+1)
    term.write("\\")
    term.setCursorPos(px+2,py+2)
    term.write("|")
    term.setCursorPos(px+2,py+3)
    term.write("|")
    term.setCursorPos(px+4,py+2)
    drawQuantumTechCoin()
  elseif id == 2 then
    --Sent QuantumTechCoin
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(16384)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+2,py)
    term.write("/\\")
    term.setCursorPos(px+2,py+1)
    term.write("||")
  elseif id == 3 then
    --Received QuantumTechCoin
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(8192)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+2,py)
    term.write("||")
    term.setCursorPos(px+2,py+1)
    term.write("\\/")
  elseif id == 4 then
    --Sent to yourself
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(16)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+1,py)
    term.write("/\\||")
    term.setCursorPos(px+1,py+1)
    term.write("||\\/")
  elseif id == 5 then
    --Swept from v1 address
    term.setCursorPos(px+1,py)
    term.setBackgroundColor(256)
    term.setTextColor(128)
    term.write(" v1 ")
    term.setCursorPos(px+2,py+1)
    term.setBackgroundColor(1)
    term.setTextColor(2048)
    term.write("||")
    term.setCursorPos(px+2,py+2)
    term.write("\\/")
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16)
    term.setTextColor(32768)
    term.write(" v2 ")
  end
end
function wallet()
  hud()
  local event, button, xPos, yPos = os.pullEvent("mouse_click")
  if gui == 1 then
    if yPos == 5 and xPos >= 3 and xPos <= 14 then
      page = 1
      balance = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..address).readAll())
    end
    if yPos == 7 and xPos >= 3 and xPos <= 14 then
      page = 2
      subject = address
      scroll = 0
    end
    if yPos == 9 and xPos >= 3 and xPos <= 14 then
      page = 3
      balance = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..address).readAll())
    end
    if yPos == 13 and xPos >= 3 and xPos <= 14 then
      page = 4
    end
    if yPos == 17 and xPos >= 3 and xPos <= 14 then
      page = 0
    end
  elseif gui == 2 then
    if yPos == 2 and xPos >= 19 and xPos <= 24 then
      page = 0
    end
  end
  if page == 1 then
    if (yPos-7)%5 == 0 and yPos >= 7 and xPos >= 26 and xPos <= 35 then
      subject = string.sub(http.get("http://coinserv.ceriat.net/c/qtc/index.php?listtx="..address.."&overview").readAll(),13+(31*((yPos-7)/5)),22+(31*((yPos-7)/5)))
      if string.len(subject) == 10 and subject ~= "N/A(Mined)" then
        page = 2
      end
    end
  elseif page == 2 then
    if yPos > 2 and yPos <= 2+ar-(16*(scroll)) and xPos >= 31 and xPos < 41 then
      if stpeer[(yPos-2)+(16*(scroll))] == "N/A(Mined)" then
        --possibly link to a block later?
      else
        subject = stpeer[(yPos-2)+(16*(scroll))]
        scroll = 0
      end
    end
    if yPos == 19 and xPos >= 32 and xPos <= 36 then
      scroll = 0
    end
    if yPos == 19 and xPos >= 38 and xPos <= 41 then
      scroll = math.max(0,scroll-1)
    end
    if yPos == 19 and xPos >= 43 and xPos <= 46 then
      scroll = math.min(lastpage,scroll+1)
    end
    if yPos == 19 and xPos >= 48 then
      scroll = lastpage
    end
    if yPos == 1 and xPos >= 17 then
      page = 6
    end
  elseif page == 3 then
    if xPos >= 17 then
      term.setCursorPos(33,5)
      local recipient = read()
      term.setCursorPos(33,6)
      local amount = read()
      local transaction = http.get("http://coinserv.ceriat.net/c/qtc/index.php?pushtx2&q="..recipient.."&pkey="..masterkey.."&amt="..amount).readAll()
      balance = tonumber(http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..address).readAll())
      term.setCursorPos(19,8)
      if transaction == "Success" then
        term.setTextColor(8192)
        term.write("Transfer successful")
        term.setTextColor(32768)
      elseif string.sub(transaction,0,5) == "Error" then
        local problem = "An unknown error happened"
        local code = tonumber(string.sub(transaction,6,10))
        if code == 1 then problem = "Insufficient funds available" end
        if code == 2 then problem = "Not enough QTC in transaction" end
        if code == 3 then problem = "Can't comprehend amount to send" end
        if code == 4 then problem = "Invalid recipient address" end
        term.setTextColor(16384)
        term.write(problem)
        term.setTextColor(32768)
      else
        term.setTextColor(16384)
        term.write(transaction)
        term.setTextColor(32768)
      end
      os.sleep(2.5) --lower this if you do tons of transfers
    end
  
  elseif page == 4 then
    if yPos == 3 and xPos >= 19 and xPos <= 31 then
      page = 5
      scroll = 0
    end
    if yPos == 3 and xPos >= 35 and xPos <= 48 then
      page = 6
    end
    if yPos == 4 and xPos >= 35 and xPos <= 46 then
      page = 7
    end
  elseif page == 5 then
    if yPos > 2 and xPos >= 27 and xPos <= 36 then
      page = 2
      subject = blkpeer[(yPos-2)]
      scroll = 0
    end
  elseif page == 6 then
    term.setCursorPos(18,1)
    term.write("                       ")
    term.setCursorPos(18,1)
    term.write("ADDRESS ")
    subject = read()
    if string.len(subject) == 10 then
      page = 2
      scroll = 0
    else
      page = 6
    end
  elseif page == 7 then
    if yPos > 2 and yPos <= 18 and xPos >= 20 and xPos < 30 then
      if blkpeer[(yPos-2)] == "N/A(Burnt)" then
        --possibly link to null later?
      else
        page = 2
        subject = blkpeer[(yPos-2)]
        scroll = 0
      end
    end
  end
end
function drawTab(text)
  term.setBackgroundColor(512)
  term.write(text)
end
function drawBtn(text)
  term.setBackgroundColor(32)
  term.write(text)
end
function hud()
  term.setBackgroundColor(1)
  term.setTextColor(32768)
  term.clear()
  if gui == 1 then
    local sidebar = 1
    while sidebar < 51 do
      term.setCursorPos(1,sidebar)
      term.setBackgroundColor(8)
      term.write("                ")
      sidebar = sidebar + 1
    end
    term.setCursorPos(2,2)
    drawQuantumTechCoin()
    term.setBackgroundColor(8)
    term.setTextColor(32768)
    term.write(" QTC Wallet")
    term.setCursorPos(5,3)
    term.setTextColor(2048)
    term.write("release "..version.."")
    term.setCursorPos(2,19)
    term.write("    by 3d6    ")
    term.setTextColor(32768)
    term.setCursorPos(3,5)
    drawTab("  Overview  ")
    term.setCursorPos(3,7)
    drawTab("Transactions")
    term.setCursorPos(3,9)
    drawTab(" Send Money ")
    term.setCursorPos(3,11)
    --drawTab("  KW Tools  ")
    term.setCursorPos(3,13)
    drawTab("   Ledger   ")
    term.setCursorPos(3,15)
    --drawTab("   Config   ")
    term.setCursorPos(3,17)
    drawTab("    Exit    ")
    term.setBackgroundColor(1)
  elseif gui == 2 then
    term.setCursorPos(1,1)
    term.setBackgroundColor(8)
    term.write("                          ")
    term.setCursorPos(1,2)
    term.write("                          ")
    term.setCursorPos(1,3)
    term.write("                          ")
    term.setCursorPos(1,4)
    term.write("                          ")
    term.setCursorPos(2,2)
    drawQuantumTechCoin()
    term.setBackgroundColor(8)
    term.setTextColor(32768)
    term.write(" QuantumTechCoinWallet")
    term.setCursorPos(5,3)
    term.setTextColor(2048)
    term.write("release "..version.."")
    term.setCursorPos(19,2)
    term.setBackgroundColor(16384)
    term.setTextColor(32768)
    term.write(" Exit ")
  end
  if page == 1 then
    term.setCursorPos(19,2)
    term.write("Your address: ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(19,3)
    term.write("Your balance: ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." QTC")
    term.setTextColor(32768)
    term.setCursorPos(19,5)
    local recenttransactions = http.get("http://coinserv.ceriat.net/c/qtc/index.php?listtx="..address.."&overview").readAll()
    local txtype = 0
    local graphics = 0
    if string.len(recenttransactions) > 25 then
      repeat
        if string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == "N/A(Mined)" then txtype = 1
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == address then txtype = 4
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == addressv1 then txtype = 5
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) < 0 then txtype = 2
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) > 0 then txtype = 3
        end
        postgraphic(19,5+(5*graphics),txtype)
        term.setCursorPos(26,5+(5*graphics))
        term.setBackgroundColor(1)
        term.setTextColor(32768)
        if txtype == 1 then term.write("Mined")
        elseif txtype == 2 then term.write("Sent")
        elseif txtype == 3 then term.write("Received")
        elseif txtype == 4 then term.write("Tumbled")
        elseif txtype == 5 then term.write("Imported")
        end
        term.setCursorPos(26,6+(5*graphics))
        if txtype == 4 then
          term.setTextColor(32768)
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) > 0 then
          term.setTextColor(8192)
          term.write("+")
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) == 0 then
          term.setTextColor(16)
        else
          term.setTextColor(16384)
        end
        term.write(tostring(tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics)))).." QTC")
        term.setCursorPos(26,7+(5*graphics))
        term.setTextColor(512)
        if txtype > 1 then term.write(string.sub(recenttransactions,13+(31*graphics),22+(31*graphics))) end
        term.setCursorPos(26,8+(5*graphics))
        term.setTextColor(128)
        term.write(string.sub(recenttransactions,1+(31*graphics),12+(31*graphics)))
        graphics = graphics + 1
      until graphics >= math.floor(string.len(recenttransactions)/32)
    end
  elseif page == 2 then
    subbal = http.get("http://coinserv.ceriat.net/c/qtc/index.php?getbalance="..subject).readAll()
    subtxs = http.get("http://coinserv.ceriat.net/c/qtc/index.php?listtx="..subject).readAll()
    term.setCursorPos(18,1)
    if subtxs == "end" then subbal = 0 end
    term.write("ADDRESS "..subject.." - "..subbal.." QTC")
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time         Peer           Value ")
    term.setBackgroundColor(1)
    if subtxs ~= "end" then
      local tx = 0
      local s = 0
      ar = 16*scroll
      repeat
        tx = tx + 1
        stdate[tx] = string.sub(subtxs,1,12)
        subtxs = string.sub(subtxs,13)
        stpeer[tx] = string.sub(subtxs,1,10)
        subtxs = string.sub(subtxs,11)
        stval[tx] = tonumber(string.sub(subtxs,1,9))
        subtxs = string.sub(subtxs,10)
        if stpeer[tx] == subject then stval[tx] = 0 end
      until string.len(subtxs) == 3
      repeat
        ar = ar + 1
        term.setTextColor(32768)
        term.setCursorPos(18,2+ar-(16*(scroll)))
        term.write(stdate[ar])
        if stpeer[ar] ~= "N/A(Mined)" then term.setTextColor(512) end
        if stpeer[ar] == subject then term.setTextColor(32768) end
        term.setCursorPos(31,2+ar-(16*(scroll)))
        term.write(stpeer[ar])
        term.setCursorPos(50-string.len(tostring(math.abs(stval[ar]))),2+ar-(16*(scroll)))
        if stval[ar] > 0 then
          term.setTextColor(8192)
          term.write("+")
        elseif stval[ar] < 0 then
          term.setTextColor(16384)
        else
          term.setTextColor(32768)
          term.write(" ")
        end
        term.write(tostring(stval[ar]))
      until ar == math.min(tx,16*(scroll+1))
      term.setBackgroundColor(256)
      term.setCursorPos(17,19)
      term.write("                                   ")
      term.setCursorPos(17,19)
      term.setTextColor(32768)
      lastpage = math.floor((tx-1)/16)
      if (1+lastpage) < 100 then maxspace = maxspace.." " end
      if (1+lastpage) < 10 then maxspace = maxspace.." " end
      if (1+scroll) < 100 then pagespace = pagespace.." " end
      if (1+scroll) < 10 then pagespace = pagespace.." " end
      term.write(" Page "..pagespace..(1+scroll).."/"..maxspace..(1+lastpage))
      pagespace = ""
      maxspace = ""
      term.setCursorPos(32,19)
      term.setTextColor(128)
      term.write("First Prev Next Last")
      if (scroll > 0) then
        term.setCursorPos(32,19)
        term.setTextColor(2048)
        term.write("First Prev")
      end
      if (scroll < lastpage and tx > 16) then
        term.setCursorPos(43,19)
        term.setTextColor(2048)
        term.write("Next Last")
      end
    else
      term.write("No transactions to display!")
      term.setBackgroundColor(256)
      term.setCursorPos(17,19)
      term.write("                                   ")
      term.setCursorPos(17,19)
      term.setTextColor(32768)
      term.write(" Page   1/  1")
      term.setCursorPos(32,19)
      term.setTextColor(128)
      term.write("First Prev Next Last")
    end
  elseif page == 3 then
    term.setCursorPos(19,2)
    term.write("Your address: ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(19,3)
    term.write("Your balance: ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." QTC")
    term.setTextColor(32768)
    term.setCursorPos(19,5)
    term.write("Recipient:    ")
    term.write("                   ")
    term.setCursorPos(19,6)
    term.write("Amount (QTC): ")
    term.write("                   ")
  elseif page == 4 then
    term.setCursorPos(19,2)
    term.write("Mining          Addresses")
    term.setTextColor(512)
    term.setCursorPos(19,3)
    term.write("Latest blocks   Address lookup")
    term.setCursorPos(19,4)
    --term.write("Lowest hashes   Rich list")
    term.write("                Top balances")
    term.setCursorPos(19,5)
    term.write("   ")
    term.setTextColor(32768)
    term.setCursorPos(19,7)
    --term.write("Economy         Transactions")
    term.setTextColor(512)
    term.setCursorPos(19,8)
    --term.write("QTC issuance    Latest transfers")
    term.setCursorPos(19,9)
    --term.write("QTC distrib.    Largest transfers")
  elseif page == 5 then
    local blocks = http.get("http://coinserv.ceriat.net/c/qtc/index.php?blocks").readAll()
    local tx = 0
    ar = 0
    local height = string.sub(blocks,1,8)
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    height = tonumber(string.sub(blocks,1,8))
    blocks = string.sub(blocks,9)
    local today = string.sub(blocks,1,10)
    blocks = string.sub(blocks,11)
    repeat
      tx = tx + 1
      blktime[tx] = string.sub(blocks,1,8)
      blocks = string.sub(blocks,9)
      blkpeer[tx] = string.sub(blocks,1,10)
      blocks = string.sub(blocks,11)
      blkhash[tx] = string.sub(blocks,1,12)
      blocks = string.sub(blocks,13)
      if stpeer[tx] == subject then stval[tx] = 0 end
    until string.len(blocks) == 0
    term.setCursorPos(18,1)
    term.write("Height: "..tostring(height))
    term.setCursorPos(36,1)
    term.write("Date: "..today)
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time     Miner      Hash          ")
    ----------(" 00:00:00 0000000000 000000000000 ")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(18,2+ar)
      term.write(blktime[ar])
      if blkpeer[ar] ~= "N/A(Burnt)" then term.setTextColor(512) end
      term.setCursorPos(27,2+ar)
      term.write(blkpeer[ar])
      term.setTextColor(32768)
      term.setCursorPos(38,2+ar)
      term.write(blkhash[ar])
    until ar == math.min(tx,17*(scroll+1))
  elseif page == 6 then
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time         Peer           Value ")
    term.setBackgroundColor(256)
    term.setCursorPos(17,19)
    term.write("                                   ")
    term.setCursorPos(17,19)
    term.setTextColor(32768)
    term.write(" Page    /")
    term.setCursorPos(32,19)
    term.setTextColor(128)
    term.write("First Prev Next Last")
    term.setBackgroundColor(1)
    term.setCursorPos(18,1)
    term.write("ADDRESS (click to edit)")
  elseif page == 7 then
    local blocks = http.get("http://coinserv.ceriat.net/c/qtc/index.php?richapi").readAll()
    local tx = 0
    ar = 0
    local height = string.sub(blocks,1,8)
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    repeat
      tx = tx + 1
      blkpeer[tx] = string.sub(blocks,1,10)
      blocks = string.sub(blocks,11)
      blktime[tx] = tonumber(string.sub(blocks,1,8))
      blocks = string.sub(blocks,9)
      blkhash[tx] = string.sub(blocks,1,11)
      blocks = string.sub(blocks,12)
    until string.len(blocks) == 0
    term.setCursorPos(18,1)
    term.write("QuantumTechCoin address rich list")
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write("R# Address     Balance First seen  ")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(17,2+ar)
      if ar < 10 then term.write(" ") end
      term.write(ar)
      term.setCursorPos(20,2+ar)
      if blkpeer[ar] ~= "N/A(Burnt)" then term.setTextColor(512) end
      term.write(blkpeer[ar])
      term.setTextColor(32768)
      term.setCursorPos(39-string.len(tostring(math.abs(blktime[ar]))),2+ar)
      term.write(blktime[ar])
      term.setCursorPos(40,2+ar)
      term.write(blkhash[ar])
    until ar == 16
  elseif page == 21 then
    term.setBackgroundColor(1)
    term.setCursorPos(4,6)
    term.write("Address - ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(4,7)
    term.write("Balance - ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." QTC")
    term.setTextColor(32768)
    term.setCursorPos(3,9)
  end
end
boot()
