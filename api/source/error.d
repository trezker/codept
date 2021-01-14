module codept.error;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;

string DeclutterErrorLog(string message) {
	string[] lines = splitLines(message);
	string[] decluttered = lines[0 .. 2];
	lines  = lines[2 .. $];
	decluttered ~= lines.filter!(line => startsWith(line, "source/")).array;

	string joined = join(decluttered, "\n");
	return joined;
}

unittest {
	import std.file : FileException, readText;
	string message = readText("testdata/error.log");
	string clean = DeclutterErrorLog(message);
	//writeln(clean);
}