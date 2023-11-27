function uploadContent() {
	if (content !== editor.getValue()) {
		var temp = editor.getValue();
		var request = new XMLHttpRequest();

		request.open('POST', window.location.href, true);
		request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
		request.onload = function() {
			if (request.readyState === 4) {
				content = temp;
				setTimeout(uploadContent, 1000);
			}
		}
		request.onerror = function() {
			setTimeout(uploadContent, 1000);
		}
		request.send('text=' + encodeURIComponent(temp));
	} else {
		setTimeout(uploadContent, 1000);
	}
}

var editor = ace.edit("editor");
var content = editor.getValue();

editor.setTheme("ace/theme/monokai");
editor.session.setMode("ace/mode/xml");
editor.setPrintMarginColumn(-1);

uploadContent();
