import vibe.vibe;
import codept.storage;
import std.stdio;

class API {
	Storage storage;
public:
	this() {
		storage = new Storage;
	}

	void SaveStory(Story story) {
		storage.SaveStory(story);
	}

	Story[] LoadBacklog() {
		return storage.LoadBacklog();
	}
};

class HTTPAPI {
	API api;
public:
	this() {
		api = new API;
	}

	void SaveStory(HTTPServerRequest req, HTTPServerResponse res) {
		Story story;
		story.title = req.json["title"].to!string;
		story.points = req.json["points"].to!int;

		api.SaveStory(story);
		Json json = Json.emptyObject;
		json["success"] = true;
		res.writeBody(serializeToJsonString(json), 200);
	}

	void LoadBacklog(HTTPServerRequest req, HTTPServerResponse res) {
		auto backlog = api.LoadBacklog();
		Json json = Json.emptyObject;
		json["success"] = true;
		json["backlog"] = serialize!(JsonSerializer, Story[])(backlog);
		res.writeBody(serializeToJsonString(json), 200);
	}
};

void index(HTTPServerRequest req, HTTPServerResponse res)
{
	Json json = Json.emptyObject;
	json["success"] = true;
	res.writeBody(serializeToJsonString(json), 200);
}

void main()
{
	HTTPAPI httpapi = new HTTPAPI;

	auto router = new URLRouter;
	router.get("/", &index);
	router.get("/api/test", &index);
	router.post("/api/savestory", &httpapi.SaveStory);
	router.post("/api/loadbacklog", &httpapi.LoadBacklog);

	auto settings = new HTTPServerSettings;
	settings.port = 8080;

	listenHTTP(settings, router);

	disableDefaultSignalHandlers();
	runApplication();
}
