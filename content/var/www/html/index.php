<?php

$path = '/config/nag.xml';

header('Cache-Control: no-cache, no-store, must-revalidate');
header('Pragma: no-cache');
header('Expires: 0');

if (isset($_POST['text'])) {
	file_put_contents($path, $_POST['text']);
	shell_exec('GIT_CONFIG_STORE_SSH_URL=' . getenv('GIT_CONFIG_STORE_SSH_URL') . ' /usr/local/bin/gen_config.sh');
	die;
}

if (isset($_GET['raw']) || strpos($_SERVER['HTTP_USER_AGENT'], 'curl') === 0 || strpos($_SERVER['HTTP_USER_AGENT'], 'Wget') === 0) {
	if (is_file($path)) {
		header('Content-type: text/plain');
		print file_get_contents($path);
	} else {
		header('HTTP/1.0 404 Not Found');
	}
	die;
}
?><!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NMS config</title>
<style type="text/css" media="screen">
#editor {
	position: absolute;
	top: 0;
	right: 0;
	bottom: 0;
	left: 0;
}
</style>

<script src="ace.js"></script>
</head>
<body>
<div id="editor"><?php
if (is_file($path)) {
	print htmlspecialchars(file_get_contents($path), ENT_QUOTES, 'UTF-8');
}
?></div>
<script src="editor.js"></script>
</body>
</html>
