import 'dart:io';

void stderrLogger(String msg, [bool isError = false]) {
  if (isError) {
    stderr.writeln('[ERROR] $msg');
  } else {
    stderr.writeln(msg);
  }
}
