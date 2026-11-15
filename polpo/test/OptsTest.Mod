MODULE OptsTest;  (* the tests of opts as programs: TestLongOption and testopts read the arguments of the
  program, so they are made with program.Make and run with fork and execve; where programs of this
  machine cannot be started (qemu without binfmt), they are only made *)

IMPORT SYSTEM, Linux0, Files, Texts, Oberon0, Out;

TYPE
  Name = ARRAY 64 OF CHAR;

VAR
  checks, fails: LONGINT;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); Out.String("FAIL "); Out.String(what); Out.String(" (case "); Out.Int(checks, 0); Out.String(")"); Out.Ln END
END Check;

PROCEDURE Make(args: ARRAY OF CHAR): BOOLEAN;
VAR par: Oberon0.ParList; W: Texts.Writer; res: INTEGER;
BEGIN
  Texts.OpenWriter(W); Texts.WriteString(W, args); Texts.WriteString(W, " ~");
  NEW(par); NEW(par.text); Texts.Open(par.text, ""); Texts.Append(par.text, W.buf); par.pos := 0;
  Oberon0.Call("program.Make", par, FALSE, res);
  RETURN res = 0
END Make;

PROCEDURE Exists(name: ARRAY OF CHAR): BOOLEAN;
VAR full: Name; flags: SET;
BEGIN RETURN Files.Exists(name, full, flags)
END Exists;

(* the exit status of ./file run with the arguments a1, a2 and a3 (empty: none); -1 when it could not
  be started *)
PROCEDURE Exec(file: ARRAY OF CHAR; VAR a1, a2, a3: ARRAY OF CHAR): LONGINT;
VAR pid, r, st: LONGINT; path: Name; argv: ARRAY 5 OF LONGINT; envp: ARRAY 1 OF LONGINT;
BEGIN
  path := "./"; r := 0; WHILE file[r] # 0X DO path[r+2] := file[r]; INC(r) END; path[r+2] := 0X;
  argv[0] := SYSTEM.ADR(path); argv[1] := 0; argv[2] := 0; argv[3] := 0; argv[4] := 0;
  IF a1[0] # 0X THEN argv[1] := SYSTEM.ADR(a1[0]) END;
  IF a2[0] # 0X THEN argv[2] := SYSTEM.ADR(a2[0]) END;
  IF a3[0] # 0X THEN argv[3] := SYSTEM.ADR(a3[0]) END;
  envp[0] := 0;
  pid := Linux0.Fork0();
  IF pid = 0 THEN
    r := Linux0.Execve0(SYSTEM.ADR(path), SYSTEM.ADR(argv), SYSTEM.ADR(envp));
    Linux0.Exit0(99)
  END;
  st := 0; r := Linux0.Waitpid0(pid, SYSTEM.ADR(st), 0);
  IF (r # pid) OR (st MOD 128 # 0) THEN RETURN -1 END;
  st := st DIV 256 MOD 256;
  IF st = 99 THEN RETURN -1 END;
  RETURN st
END Exec;

PROCEDURE Run*;
VAR n, a, b: ARRAY 8 OF CHAR; long: ARRAY 302 OF CHAR; i: INTEGER; st: LONGINT;
BEGIN
  checks := 0; fails := 0;
  Check("TestLongOption made", Make("/out zq_longoption TestLongOption.Mod") & Exists("zq_longoption"));
  Check("testopts made", Make("/out zq_testopts testopts.Mod") & Exists("zq_testopts"));
  i := 0; WHILE i < 300 DO long[i] := "x"; INC(i) END; long[300] := 0X;
  n := "-n"; a := "tail";
  st := Exec("zq_longoption", n, long, a);
  IF st = -1 THEN
    Out.String("OptsTest: the programs cannot be started here, not run"); Out.Ln
  ELSE
    Check("a value of 300 characters and a positional argument", st = 0);
    n := "-m"; a := "Main"; b := "-s";
    Check("testopts with a required option", Exec("zq_testopts", n, a, b) = 0);
    a := "";
    Check("an option without its value: exit status 5", Exec("zq_testopts", n, a, a) = 5)
  END;
  IF fails = 0 THEN Out.String("OptsTest: passed, ") ELSE Out.String("OptsTest: ") END;
  Out.Int(checks, 0); Out.String(" checks, "); Out.Int(fails, 0); Out.String(" failed"); Out.Ln
END Run;

END OptsTest.
