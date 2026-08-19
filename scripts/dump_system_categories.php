<?php
/**
 * Dump EasyFinance system categories from the server database.
 *
 * PHP 5.x compatible (no ?? operator, no arrow functions, uses array()).
 *
 * Place this file in the project root on the server (e.g. /var/www/easyfinance.ru/sf)
 * and run:
 *     php scripts/dump_system_categories.php
 *
 * If auto-detection of DB credentials fails, fill $MANUAL below and re-run.
 */

error_reporting(E_ALL);

$MANUAL = array(); // e.g. array('host' => 'localhost', 'dbname' => 'easyfinance', 'user' => 'root', 'pass' => '')

function find_configs() {
    $scriptDir = dirname(__FILE__);
    $roots = array($scriptDir);
    $p = $scriptDir;
    for ($i = 0; $i < 5; $i++) {
        $p = dirname($p);
        if ($p === '.' || $p === '/' || $p === '') break;
        $roots[] = $p;
    }
    $names = array(
        'config/databases.yml',
        'application/configs/application.ini',
        'application/configs/databases.yml',
        'app/config/parameters.yml',
        'config/parameters.ini',
        'config/parameters.php',
        'application/configs/application.php',
        'config/autoload/boot.php',
    );
    $found = array();
    foreach ($roots as $root) {
        foreach ($names as $n) {
            $path = rtrim($root, '/') . '/' . $n;
            if (is_file($path)) {
                $found[] = $path;
            }
        }
    }
    return $found;
}

function gather_from_scalar($value, &$c) {
    if (!is_string($value)) return;
    if ($c['dbname'] === null && preg_match('/dbname=([^;\'"]+)/', $value, $m)) {
        $c['dbname'] = $m[1];
    }
    if ($c['host'] === null && preg_match('/host=([^;\'"]+)/', $value, $m)) {
        $c['host'] = $m[1];
    }
    if ($c['user'] === null && preg_match('/username=([^;\'"]+)/', $value, $m)) {
        $c['user'] = $m[1];
    }
    if ($c['pass'] === null && preg_match('/password=([^;\'"]+)/', $value, $m)) {
        $c['pass'] = $m[1];
    }
}

function ini_search($arr, &$c) {
    if (!is_array($arr)) {
        gather_from_scalar($arr, $c);
        return;
    }
    $map = array(
        'host' => 'host',
        'dbname' => 'dbname',
        'username' => 'user',
        'user' => 'user',
        'password' => 'pass',
    );
    foreach ($arr as $k => $v) {
        $lk = strtolower((string)$k);
        if (is_array($v)) {
            ini_search($v, $c);
        } else {
            foreach ($map as $frag => $target) {
                if (strpos($lk, $frag) !== false && $c[$target] === null) {
                    $c[$target] = $v;
                }
            }
            gather_from_scalar($v, $c);
        }
    }
}

function parse_creds($path) {
    $c = array('host' => null, 'dbname' => null, 'user' => null, 'pass' => null);
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if ($ext === 'ini') {
        $ini = @parse_ini_file($path, true);
        if (is_array($ini)) {
            ini_search($ini, $c);
        }
    } elseif ($ext === 'yml' || $ext === 'yaml') {
        $txt = (string)@file_get_contents($path);
        if ($c['dbname'] === null && preg_match('/dbname=([^;\'"]+)/', $txt, $m)) $c['dbname'] = $m[1];
        if ($c['host'] === null && preg_match('/host=([^;\'"]+)/', $txt, $m)) $c['host'] = $m[1];
        if ($c['user'] === null && preg_match('/username:\s*[\'"]?([^\s\'"]+)/', $txt, $m)) $c['user'] = $m[1];
        if ($c['pass'] === null && preg_match('/password:\s*[\'"]?([^\s\'"]+)/', $txt, $m)) $c['pass'] = $m[1];
    }
    return $c;
}

function mask($v) {
    if ($v === null || $v === '') return '(empty)';
    return $v;
}

// --- main ---
$creds = $MANUAL;
if (!is_array($creds) || count($creds) === 0 || $creds['dbname'] === null) {
    $configs = find_configs();
    echo "Config files found:\n";
    foreach ($configs as $cf) {
        echo "  - $cf\n";
    }
    if (count($configs) === 0) {
        echo "No config auto-detected. Please fill \$MANUAL at the top of this script.\n";
        exit(1);
    }
    $best = array('host' => null, 'dbname' => null, 'user' => null, 'pass' => null);
    foreach ($configs as $cf) {
        $c = parse_creds($cf);
        foreach (array('host', 'dbname', 'user', 'pass') as $key) {
            if ($best[$key] === null && $c[$key] !== null) {
                $best[$key] = $c[$key];
            }
        }
    }
    $creds = $best;
}

echo "Using DB: host=" . mask($creds['host']) . " dbname=" . mask($creds['dbname']) .
     " user=" . mask($creds['user']) . " pass=" . (($creds['pass'] === null || $creds['pass'] === '') ? '(empty)' : '***') . "\n";

$host = ($creds['host'] === null || $creds['host'] === '') ? 'localhost' : $creds['host'];
$conn = @mysqli_connect($host, $creds['user'], $creds['pass'], $creds['dbname']);
if (!$conn) {
    echo "DB connect failed: " . mysqli_connect_error() . "\n";
    exit(1);
}
mysqli_set_charset($conn, 'utf8');

$res = mysqli_query($conn, "SHOW TABLES");
if (!$res) {
    echo "SHOW TABLES failed: " . mysqli_error($conn) . "\n";
    exit(1);
}
$tables = array();
while ($row = mysqli_fetch_row($res)) {
    $tables[] = $row[0];
}

$categoryTables = array();
foreach ($tables as $t) {
    $low = strtolower($t);
    if (strpos($low, 'categor') !== false || strpos($low, 'system') !== false) {
        $categoryTables[] = $t;
    }
}

if (count($categoryTables) === 0) {
    echo "No tables matching 'categor' or 'system' found. All tables:\n";
    foreach ($tables as $t) {
        echo "  - $t\n";
    }
    exit(0);
}

foreach ($categoryTables as $t) {
    echo "\n=== TABLE: $t ===\n";
    $r = mysqli_query($conn, "SELECT * FROM `$t` LIMIT 300");
    if (!$r) {
        echo "  query failed: " . mysqli_error($conn) . "\n";
        continue;
    }
    $fields = mysqli_fetch_fields($r);
    $colNames = array();
    foreach ($fields as $f) {
        $colNames[] = $f->name;
    }
    echo "  columns: " . implode(', ', $colNames) . "\n";
    $n = 0;
    while ($row = mysqli_fetch_assoc($r)) {
        $parts = array();
        foreach ($row as $k => $v) {
            $parts[] = $k . '=' . $v;
        }
        echo "  " . implode(' | ', $parts) . "\n";
        $n++;
        if ($n >= 300) break;
    }
    echo "  (rows shown: $n)\n";
}

mysqli_close($conn);
