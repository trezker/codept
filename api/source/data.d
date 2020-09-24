module codept.data;

struct Story {
	int id;
	string title;
	int cost;
	int value;
};

struct User {
	int id;
	string name;
	string password;
};

struct APISession {
	int id;
	int userid;
	string sessionid;
};

struct MysqlParams {
	string url;
	string port;
	string user;
	string password;
	string database;
};
