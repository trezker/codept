import vibe.vibe;
import std.stdio;
import codept.httpapi;

void index(HTTPServerRequest req, HTTPServerResponse res) {
	Json json = Json.emptyObject;
	json["success"] = true;
	res.writeBody(serializeToJsonString(json), 200);
}

void error(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo err) {
	Json json = Json.emptyObject;
	json["success"] = false;
	res.writeBody(serializeToJsonString(json), 200);
	auto f = File("/log/error.log", "a");
	f.write(err.debugMessage ~ "\n\n");
}

void main() {
	HTTPAPI httpapi = new HTTPAPI;

	auto router = new URLRouter;
	router.post("/api/login", &httpapi.Login);
	router.any("*", &httpapi.CheckLogin);
	router.get("/", &index);
	router.get("/api/test", &index);
	router.post("/api/savestory", &httpapi.SaveStory);
	router.post("/api/loadbacklog", &httpapi.LoadBacklog);
	router.post("/api/cancelstory", &httpapi.CancelStory);
	router.post("/api/donestory", &httpapi.DoneStory);
	router.post("/api/cancelledstories", &httpapi.CancelledStories);
	router.post("/api/donestories", &httpapi.DoneStories);
	router.post("/api/createuser", &httpapi.CreateUser);
	router.post("/api/logout", &httpapi.Logout);

	auto settings = new HTTPServerSettings;
	settings.sessionStore = new MemorySessionStore;
	settings.errorPageHandler = toDelegate(&error);
	settings.port = 8080;

	listenHTTP(settings, router);

	disableDefaultSignalHandlers();
	runApplication();
}
