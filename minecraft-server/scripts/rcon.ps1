# Client RCON minimal (attend $rconPort et $rconPass definis par l'appelant)
function Read-Exact($s, $n) {
  $buf = New-Object byte[] $n; $off = 0
  while ($off -lt $n) { $r = $s.Read($buf, $off, $n - $off); if ($r -le 0) { throw 'connexion fermee' }; $off += $r }
  , $buf
}
function Send-Packet($s, $id, $type, $body) {
  $b = [Text.Encoding]::UTF8.GetBytes($body)
  $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter($ms)
  $w.Write([int](10 + $b.Length)); $w.Write([int]$id); $w.Write([int]$type)
  $w.Write([byte[]]$b); $w.Write([byte]0); $w.Write([byte]0); $w.Flush()
  $bytes = $ms.ToArray(); $s.Write($bytes, 0, $bytes.Length)
}
function Read-Packet($s) {
  $len = [BitConverter]::ToInt32((Read-Exact $s 4), 0)
  $d = Read-Exact $s $len
  [pscustomobject]@{ Id = [BitConverter]::ToInt32($d, 0); Type = [BitConverter]::ToInt32($d, 4); Body = [Text.Encoding]::UTF8.GetString($d, 8, $len - 10) }
}
function Invoke-Rcon($cmd) {
  try {
    $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $rconPort)
    $c.ReceiveTimeout = 5000
    $s = $c.GetStream()
    Send-Packet $s 1 3 $rconPass
    do { $p = Read-Packet $s } while ($p.Type -ne 2)
    if ($p.Id -eq -1) { $c.Close(); return 'RCON : mot de passe refuse.' }
    Send-Packet $s 2 2 $cmd
    $r = Read-Packet $s
    $c.Close()
    if ($r.Body) { return $r.Body } else { return '(ok)' }
  } catch { return 'Serveur injoignable : est-il demarre (LANCER.bat) ?' }
}
