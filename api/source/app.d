import vibe.vibe;
import codept.storage;
import std.stdio;

class API {
	Storage storage;
public:
	this() {
		MysqlParams params;
		auto file = File(".env");
		auto range = file.byLine();
		foreach (line; range)
		{
			auto keyval = line.split("=");
			if(keyval[0]=="DB_USER") {
				params.user = keyval[1].idup();
			}
			if(keyval[0]=="DB_CODEPT_PASSWORD") {
				params.password = keyval[1].idup();
			}
			if(keyval[0]=="DB_URL") {
				params.url = keyval[1].idup();
			}
			if(keyval[0]=="DB_DATABASE") {
				params.database = keyval[1].idup();
			}
			if(keyval[0]=="DB_PORT") {
				params.port = keyval[1].idup();
			}
		}

		storage = new Storage(params);
	}

	void SaveStory(Story story) {
		storage.SaveStory(story);
	}

	Story[] LoadBacklog() {
		return storage.LoadBacklog();
	}

	void CancelStory(int id) {
		storage.CancelStory(id);
	}

	void DoneStory(int id) {
		storage.DoneStory(id);
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
		story.id = req.json["id"].to!int;
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

	void CancelStory(HTTPServerRequest req, HTTPServerResponse res) {
		int id = req.json["id"].to!int;

		api.CancelStory(id);
		Json json = Json.emptyObject;
		json["success"] = true;
		res.writeBody(serializeToJsonString(json), 200);
	}

	void DoneStory(HTTPServerRequest req, HTTPServerResponse res) {
		int id = req.json["id"].to!int;

		api.DoneStory(id);
		Json json = Json.emptyObject;
		json["success"] = true;
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
	router.post("/api/cancelstory", &httpapi.CancelStory);
	router.post("/api/donestory", &httpapi.DoneStory);

	auto settings = new HTTPServerSettings;
	settings.port = 8080;

	listenHTTP(settings, router);

	disableDefaultSignalHandlers();
	runApplication();
}
