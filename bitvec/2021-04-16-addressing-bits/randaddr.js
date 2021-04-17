function random_addr(align) {
	function random_hex(align) {
	  if (align == undefined) {
		align = 1;
	  }
	  var num = Math.floor(Math.random() *16);
	  num = Math.floor(num / align)* align;
	  return "0123456789abcdef"[num];
	}
	var out = `0x00_00_${random_hex(1) & 7}`;
	for (var idx = 11; idx > 1; --idx) {
	  if (idx % 2 == 0) {
		out += "_";
	  }
	  out += random_hex(1);
	}
	out += random_hex(align);
	return out;
}

var regen_interval = 1500;
var regen_id = window.setTimeout(regen, regen_interval);
function regen() {
	window.clearTimeout(regen_id);
	regen_interval *= 1.1;
	let texts = document.querySelectorAll("pre[data-contents=\"pointer\"] code");
	function set_text(slot, text) {
	  slot.innerText = text;
	}

	set_text(texts[0], random_addr(1));
	set_text(texts[1], random_addr(2));
	set_text(texts[2], random_addr(4));
	set_text(texts[3], random_addr(8));
	regen_id = window.setTimeout(regen, regen_interval);
}
