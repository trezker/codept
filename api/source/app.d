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

	Story[] CancelledStories() {
		return storage.CancelledStories();
	}

	Story[] DoneStories() {
		return storage.DoneStories();
	}

	void CancelStory(int id) {
		storage.CancelStory(id);
	}

	void DoneStory(int id) {
		storage.DoneStory(id);
	}

	void CreateUser(User user) {
		storage.CreateUser(user);
	}

	string Login(User user) {
		return storage.Login(user);
	}

	bool IsLoggedIn(string sessionid) {
		auto session = storage.LoadSession(sessionid);
		if(session.userid != 0) {
			return true;
		}
		return false;
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
		story.cost = req.json["cost"].to!int;
		story.value = req.json["value"].to!int;

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

	void CancelledStories(HTTPServerRequest req, HTTPServerResponse res) {
		auto stories = api.CancelledStories();
		Json json = Json.emptyObject;
		json["success"] = true;
		json["stories"] = serialize!(JsonSerializer, Story[])(stories);
		res.writeBody(serializeToJsonString(json), 200);
	}

	void DoneStories(HTTPServerRequest req, HTTPServerResponse res) {
		auto stories = api.DoneStories();
		Json json = Json.emptyObject;
		json["success"] = true;
		json["stories"] = serialize!(JsonSerializer, Story[])(stories);
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

	void CreateUser(HTTPServerRequest req, HTTPServerResponse res) {
		User user;
		user.name = req.json["name"].to!string;
		user.password = req.json["password"].to!string;

		api.CreateUser(user);
		Json json = Json.emptyObject;
		json["success"] = true;
		res.writeBody(serializeToJsonString(json), 200);
	}

	void Login(HTTPServerRequest req, HTTPServerResponse res) {
		User user;
		user.name = req.form["name"];
		user.password = req.form["password"];

		if("create" == req.form["button"]) {
			api.CreateUser(user);
		}

		string sessionid = api.Login(user);

		if(sessionid != "") {
			auto session = res.startSession();
			session.set("sessionid", sessionid);
			res.redirect("/");
		} else {
			res.redirect("/login.html");
		}
	}

	void CheckLogin(HTTPServerRequest req, HTTPServerResponse res) {
		Json json = Json.emptyObject;
		json["loggedin"] = false;
		if (!req.session) {
			res.writeBody(serializeToJsonString(json), 200);
		} else {
			string sessionid = req.session.get!string("sessionid");
			if(!api.IsLoggedIn(sessionid)) {
				res.writeBody(serializeToJsonString(json), 200);
			}
		}
	}
};

void index(HTTPServerRequest req, HTTPServerResponse res) {
	Json json = Json.emptyObject;
	json["success"] = true;
	res.writeBody(serializeToJsonString(json), 200);
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

	auto settings = new HTTPServerSettings;
	settings.sessionStore = new MemorySessionStore;
	settings.port = 8080;

	listenHTTP(settings, router);

	disableDefaultSignalHandlers();
	runApplication();
}
