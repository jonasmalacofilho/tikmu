import Error;
import croxit.Web;
import db.Context;
import mweb.Dispatcher;
import mweb.tools.*;
import org.mongodb.Mongo;
import routes.nonroute.*;
import routes.search.SearchRoute;
using Lambda;

class Main
{
	static function handleLoggedMeta(ctx:Context, metas:Array<String>)
	{
		if (!metas.has("openRoute"))
		{
			var s = ctx.session;
			if (s == null)
				throw NotLogged;
			else if (!s.isValid())
				throw ExpiredSession(s);
		}
	}

	static function main()
	{
		haxe.Log.trace = function (msg, ?p) {
			var s = '[${Date.now()}][${Web.getClientIP()}] ${p.fileName}:${p.lineNumber}:  $msg\n';
			Sys.stderr().writeString(s);
		}

		var mongo = new Mongo();
		var ctx = new db.Context(mongo.tikmu);

		var cookies = Web.getCookies();
		// handle session
		if (cookies.exists("_session"))
		{
			var sid = cookies.get("_session");
			if (sid == "")
				ctx.session = null;
			else
				ctx.session = ctx.sessions.get(sid);
		}

		var d = new Dispatcher(Web);
		d.addMetaHandler(handleLoggedMeta.bind(ctx));

		var route = mweb.Route.anon({
			login: new routes.login.LoginRoute(ctx),
			register: new routes.register.RegisterRoute(ctx),
			list: new routes.list.ListRoute(ctx),
			listfavorites: new routes.list.ListFavoritesRoute(ctx),
			ask: new routes.ask.AskRoute(ctx),
			question: new routes.question.QuestionRoute(ctx),
			search: new routes.search.SearchRoute(ctx),
			anyDefault: @openRoute function(d:Dispatcher<Dynamic>) return d.getRoute(routes.list.ListRoute).anyDefault(),
			//These will be changed to remoting functions:
			deletequestion : new routes.nonroute.NonRouteFunctions.DeleteQuestion(ctx),
			editquestion : new routes.nonroute.NonRouteFunctions.EditQuestion(ctx),
			deleteanswer : new routes.nonroute.NonRouteFunctions.DeleteAnswer(ctx),
			editanswer : new routes.nonroute.NonRouteFunctions.EditAnswer(ctx),
			deletecomment : new routes.nonroute.NonRouteFunctions.DeleteComment(ctx),
			editcomment : new routes.nonroute.NonRouteFunctions.EditComment(ctx),
			markquestionassolved : new routes.nonroute.NonRouteFunctions.MarkQuestionAsSolved(ctx),
			togglefavorite : new routes.nonroute.NonRouteFunctions.ToggleFavorite(ctx),
			togglefollow : new routes.nonroute.NonRouteFunctions.ToggleFollow(ctx)
		});

		var ret:HttpResponse<Dynamic>;
		try {
			ret = d.dispatch(route);
		} catch (e:AuthorizationError) {
			trace(e);
			ret = HttpResponse.empty().redirect('/login');
		}

		new HttpWriter(new NekoWebWriter()).writeResponse(ret);
	}
}