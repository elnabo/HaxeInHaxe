package typing.matcher;

import haxe.EnumTools.EnumValueTools;
import haxe.ds.ImmutableList;

import ocaml.List;
using equals.Equal;

enum Constructor_T {
	ConConst(c:core.Type.TConstant);
	ConEnum(e:core.Type.TEnum, ef:core.Type.TEnumField);
	ConStatic(c:core.Type.TClass, cf:core.Type.TClassField);
	ConTypeExpr(mt:core.Type.ModuleType);
	ConFields(l:ImmutableList<String>);
	ConArray(i:Int);
}

abstract Constructor (Constructor_T) from Constructor_T to Constructor_T {
	public static function to_string(con:Constructor) : String {
		return switch (con) {
			case ConConst(ct): core.Type.s_const(ct);
			case ConEnum(en, ef): ef.ef_name;
			case ConStatic(c, cf): '${core.Globals.s_type_path(switch (c.cl_kind) { case KAbstractImpl(a): a.a_path; case _: c.cl_path;})}.${cf.cf_name}';
			case ConTypeExpr(mt): core.Globals.s_type_path(core.Type.t_infos(mt).mt_path);
			case ConFields(fields): '{ ${List.join(", ", fields)} }';
			case ConArray(i): '<array ${i}>';
		}
	}

	public static function equal(con1:Constructor, con2:Constructor) : Bool {
		return switch [con1, con2] {
			case [ConConst(ct1), ConConst(ct2)]:
				ct1.equals(ct2);
			case [ConEnum(en1, ef1), ConEnum(en2, ef2)]:
				en1.equals(en2) && ef1.equals(ef2);
			case [ConStatic(c1, cf1), ConStatic(c2, cf2)]:
				c1.equals(c2) && cf1.equals(cf2);
			case [ConTypeExpr(mt1), ConTypeExpr(mt2)]:
				mt1.equals(mt2);
			case [ConFields(_), ConFields(_)]: true;
			case [ConArray(i1), ConArray(i2)]: i1.equals(i2);
			case _: false;
		}
	}

	public static function arity (con:Constructor) : Int {
		return switch (con) {
			case ConEnum(_, {ef_type:TFun({args:args})}): List.length(args);
			case ConEnum(_, _): 0;
			case ConConst(_): 0;
			case ConFields(fields): List.length(fields);
			case ConArray(i): i;
			case ConTypeExpr(_): 0;
			case ConStatic(_):0;
		}
	}

	public static function compare(con1:Constructor, con2:Constructor) : Int {
		return switch [con1, con2] {
			case [ConConst(ct1), ConConst(ct2)]:
				switch [ct1, ct2] {
					case [TInt(i1), TInt(i2)]: compareInt(i1, i2);
					case [TString(s1), TString(s2)], [TFloat(s1), TFloat(s2)]: compareString(s1, s2);
					case [TBool(b1), TBool(b2)]:
						if (b1 == b2) { 0; }
						else if (b1 && !b2) { 1; }
						else { -1; }
					case [TNull, TNull], [TThis, TThis], [TSuper, TSuper]: 0;
					case _:
						compareInt(EnumValueTools.getIndex(ct1), EnumValueTools.getIndex(ct2));
				}
			case [ConEnum(en1, ef1), ConEnum(en2, ef2)]:
				compareInt(ef1.ef_index, ef2.ef_index);
			case [ConStatic(c1, cf1), ConStatic(c2, cf2)]:
				compareString(cf1.cf_name, cf2.cf_name);
			case [ConTypeExpr(mt1), ConTypeExpr(mt2)]:
				var e1 = core.Type.t_infos(mt1).mt_path;
				var e2 = core.Type.t_infos(mt2).mt_path;
				core.Path.compare(e1, e2);
			case [ConFields(_), ConFields(_)]: 0;
			case [ConArray(i1), ConArray(i2)]: i1 - i2;
			case _: -1; // Could assert...
		}
	}

	public static function to_texpr (ctx:context.Typecore.Typer, match_debug:Bool, p:core.Globals.Pos, con:Constructor) : core.Type.TExpr {
		return switch (con) {
			case ConEnum(en, ef):
				if (core.Meta.has(FakeEnum, en.e_meta)) {
					var e_mt = context.Typecore.type_module_expr_ref.get()(ctx, TEnumDecl(en), None, p);
					core.Type.mk(TField(e_mt, FEnum(en, ef)), ef.ef_type, p);
				}
				else if (match_debug) {
					core.Type.mk(TConst(TString(ef.ef_name)), ctx.t.tstring, p);
				}
				else {
					core.Type.mk(TConst(TInt(ef.ef_index)), ctx.t.tint, p);
				}
			case ConConst(ct): core.Texpr.Builder.make_const_texpr(ctx.com.basic, ct, p);
			case ConArray(i): core.Texpr.Builder.make_int(ctx.com.basic, i, p);
			case ConTypeExpr(mt): typing.Typer.type_module_type(ctx, mt, None, p);
			case ConStatic(c, cf): core.Texpr.Builder.make_static_field(c, cf, p);
			case ConFields(_): core.Error.error("Something went wrong", p);
		}
	}

	static function compareInt(i1:Int, i2:Int) : Int {
		if (i1 == i2) {
			return 0;
		}
		else if ( i1 < i2 ) {
			return -1;
		}
		else {
			return 1;
		}
	}
	static function compareString(s1:String, s2:String) : Int {
		if (s1 == s2) {
			return 0;
		}
		else if ( s1 < s2 ) {
			return -1;
		}
		else {
			return 1;
		}
	}
}