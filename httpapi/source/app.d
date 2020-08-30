import vibe.vibe;

void index(HTTPServerRequest req, HTTPServerResponse res)
{
	Json json = Json.emptyObject;
	json["success"] = true;
	res.writeBody(serializeToJsonString(json), 200);
}

void main()
{
	auto router = new URLRouter;
	router.get("/", &index);

	auto settings = new HTTPServerSettings;
	settings.port = 8090;

	listenHTTP(settings, router);

	disableDefaultSignalHandlers();
	runApplication();
}
