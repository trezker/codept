module codept.httpapi;

import vibe.vibe;

import codept.api;
import codept.data;

class HTTPAPI {
	API api;
public:
	this() {
		api = new API;
	}

	void SaveStory(HTTPServerRequest req, HTTPServerResponse res) {
		Story story;
		story.id = req.json["id"].to!string;
		story.productid = req.json["productID"].to!string;
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
		auto id = req.json["id"].to!string;

		api.CancelStory(id);
		Json json = Json.emptyObject;
		json["success"] = true;
		res.writeBody(serializeToJsonString(json), 200);
	}

	void DoneStory(HTTPServerRequest req, HTTPServerResponse res) {
		auto id = req.json["id"].to!string;

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
			auto session = req.session;
			if(!session) {
				session = res.startSession();
			}
			session.set("sessionid", sessionid);
			res.redirect("/");
		} else {
			res.redirect("/login.html");
		}
	}

	void Logout(HTTPServerRequest req, HTTPServerResponse res) {
		string sessionid = req.session.get!string("sessionid");
		api.Logout(sessionid);
		Json json = Json.emptyObject;
		json["loggedin"] = false;
		res.writeBody(serializeToJsonString(json), 200);
	}

	void CheckLogin(HTTPServerRequest req, HTTPServerResponse res) {
		if (
			!req.session ||
			!api.IsLoggedIn(req.session.get!string("sessionid")))
		{
			Json json = Json.emptyObject;
			json["loggedin"] = false;
			res.writeBody(serializeToJsonString(json), 200);
		}
	}
};
