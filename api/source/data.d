module codept.data;

struct Story {
	int id;
	int productid;
	string title;
	int cost;
	int value;
};

struct User {
	string id;
	string name;
	string password;
};

struct APISession {
	int id;
	string userid;
	string sessionid;
};

struct MysqlParams {
	string url;
	string port;
	string user;
	string password;
	string database;
};

struct Product {
	int id;
	string userid;
	string title;
};