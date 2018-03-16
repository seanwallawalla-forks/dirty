implementation module runtime

import types, atomics, arithmetic, builtins, utilities, unicode, stacks, native
import StdEnv, StdLib, System.IO, System.Time, Math.Random, Text
from Math.Geometry import pi
import qualified Data.Generics.GenParse as GenParse

unsafe :: !(*World -> *(.a, !*World)) -> .a
unsafe fn = fst (fn newWorld)

newWorld :: *World
newWorld = code inline {
	fillI 65536 0
}
	
MEM_TO_STR memory=:{note, left, right, above, below}
	:== "{note="<+note<+",left="<+left<+",right="<+right<+",main="<+above<+",base="<+below<+"}"

TRAVERSE_SOME dist state=:{location, direction}
	:== case direction of
		East = {state&location={location&x=location.x+dist}}
		West = {state&location={location&x=location.x-dist}}
		North = {state&location={location&y=location.y-dist}}
		South = {state&location={location&y=location.y+dist}}

TRAVERSE_ONE :== TRAVERSE_SOME 1

evaluate :: ![String] *World -> *(Memory, *World)
evaluate args world
	| isEmpty args
		# (Timestamp seed, world) = time world
		= ({note=NaN,left=zero,right=zero,above=zero,below=zero,random=genRandInt seed}, world)
	| otherwise
		# ((seed, world), args) = case (parseInt (hd args), world) of
			(Just seed, world) = ((seed, world), tl args)
			(Nothing, world) = ((\(Timestamp seed, world) -> (seed, world))(time world), args)
		= ({note=NaN,left=zero,right=zero,above=zero,below=zero,random=genRandInt seed}, world)
where

	parseArgs :: [String] -> [Element]
	parseArgs [] = []
	parseArgs [head:tail] = [parseArg head:parseArgs tail]
	where
		parseArg arg
			# try = parseString arg
			| isJust try
				# (Just try) = try
				= fromStrictList [!fromInt el \\ el <- utf8ToUnicode try] True
			# try = parseInts arg
			| isJust try
				# (Just try) = try
				= fromStrictList [!fromInt el \\ el <- try] True
			# try = parseReals arg
			| isJust try
				# (Just try) = try
				= fromStrictList [!fromReal el \\ el <- try] True
			| otherwise
				= abort "Invalid memory arguments!"

	parseInt :: (String -> (Maybe Int))
	parseInt => 'GenParse'.parseString
	
	parseString :: (String -> (Maybe String))
	parseString => 'GenParse'.parseString
	
	parseInts :: (String -> (Maybe [Int]))
	parseInts => 'GenParse'.parseString
	
	parseReals :: (String -> (Maybe [Real]))
	parseReals => 'GenParse'.parseString

initialize :: !Program ![String] *World -> (State, Memory, *World)
initialize program=:{commands} args world
	# (memory=:{random=[randpos,randdir:random]}, world)
		= evaluate args world
	| isEmpty annotated
		= ({direction=East, location={x=0,y=0}, history='\n', terminate=False}, {memory&random=random}, world)
	# (orn, loc)
		= annotated !! (randpos rem (length annotated))
	# dir = case orn of
		(Axis Vertical) = if(isEven randdir) North South
		(Axis Horizontal) = if(isEven randdir) East West
		(Dir dir) = dir
	| otherwise
		= ({direction=dir, location=loc, history='\n', terminate=False}, {memory&random=random}, world)
where
	annotated => [(orn, {x=x, y=y}) \\ y <- [0..] & line <-: commands, x <- [0..] & (Control (Start orn)) <-: line]


construct :: !Program !Flags -> (*(State, Memory, *World) -> *World)
construct program=:{dimension, source, commands, wrapping} flags = execute
where

	execute :: *(!State, !Memory, !*World) -> *World
	
	execute ({terminate=True}, memory, world)
		| flags.dump
			=  (execIO (putStrLn (MEM_TO_STR memory)) world)
		| otherwise
			=  world
	
	execute smw=:(state=:{location, direction, history}, memory, world)
		| 0 > location.x || location.x >= dimension.x || 0 > location.y || location.y >= dimension.y = let
			wrappedLocation = {x=(location.x + dimension.x) rem dimension.x, y=(location.y + dimension.y) rem dimension.y}
			in execute ({state&location=wrappedLocation,terminate=not wrapping}, memory, world)
		| otherwise
			#! (state, memory, world) = process commands.[location.y, location.x] smw
			=  (execute (TRAVERSE_ONE {state&history=source.[location.y, location.x]}, memory, world))
			
	writeLine :: !(Stack Number) -> (IO ())
	
	writeLine stack = putStrLn (if(flags.nums) (toString stack)  (if(flags.native) toString unicodeToUTF8 (map toInt (toList stack))))
	
	writeChar :: !Number -> (IO ())
	
	writeChar char = putStr (if(flags.nums) (char<+"\n") (if(flags.native) toString unicodeToUTF8 [toInt char]))
	
	readLine :: (*World -> ([Number], *World))
	readLine => app2 (map fromInt o if(flags.native) (map fromChar o fromString) utf8ToUnicode, id) o evalIO getLine
	
	readChar :: (*World -> (Number, *World))
	readChar => if(flags.native) (app2 (fromInt o fromChar, id) o evalIO getChar)(app2 (hd o map fromInt o utf8ToUnicode, id) o getUTF8 o evalIO getChar)
	where 
		
		getUTF8 :: !(!Char, !*World) -> (String, *World)
		getUTF8 (chr, world)
			| chr < '\302'
				= ({#chr}, world)
			# (str, world)
				= getMore ({#chr}, world)
			| chr < '\340'
				= (str, world)
			# (str, world)
				= getMore (str, world)
			| chr < '\360'
				= (str, world)
			| otherwise
				= getMore (str, world)
				
		getMore :: !(!String, !*World) -> (String, *World)
		getMore (str, world)
			# (chr, world) = evalIO getChar world
			= (str <+ chr, world)

	process :: !Command -> *(*(!State, !Memory, !*World) -> *(State, Memory, *World))
	
	process (Control (Terminate)) = app3 (\state -> {state&terminate=True}, id, id)

	process (Control (NOOP)) = id
		
	process (Control (Start _)) = id
		
	process (Control (Change dir)) = app3(\state -> {state&direction=dir}, id, id)
	
	process (Control (Bounce dir)) = app3(bounce, id, id)
	where
	
		bounce state=:{direction, location={x, y}}
			= case (dir, direction) of
				(NorthEast, West) = {state&direction=North,location={x=x+1,y=y}}
				(NorthEast, South) = {state&direction=East,location={x=x,y=y-1}}
				(NorthEast, North) = {state&location={x=x+1,y=y}}
				(NorthEast, East) = {state&location={x=x,y=y-1}}
				(SouthEast, West) = {state&direction=South,location={x=x+1,y=y}}
				(SouthEast, North) = {state&direction=East,location={x=x,y=y+1}}
				(SouthEast, South) = {state&location={x=x+1,y=y}}
				(SouthEast, East) = {state&location={x=x,y=y+1}}
				(SouthWest, East) = {state&direction=South,location={x=x-1,y=y}}
				(SouthWest, North) = {state&direction=West,location={x=x,y=y+1}}
				(SouthWest, South) = {state&location={x=x-1,y=y}}
				(SouthWest, West) = {state&location={x=x,y=y+1}}
				(NorthWest, East) = {state&direction=North,location={x=x-1,y=y}}
				(NorthWest, South) = {state&direction=West,location={x=x,y=y-1}}
				(NorthWest, North) = {state&location={x=x-1,y=y}}
				(NorthWest, West) = {state&location={x=x,y=y-1}}
	
	process (Control (Either axes)) = either
	where
	
		either (state, memory=:{random=[rng:random]}, world) = let
			newDirection = case axes of
				Horizontal = if(isEven rng) East West
				Vertical = if(isEven rng) North South
		in ({state&direction=newDirection}, {memory&random=random}, world)
		
	process (Control (Mirror cond axes)) = mirror
	where
		
		mirror (state=:{direction}, memory=:{above={head={head=mid}}}, world)
			| axesCollide direction && (cond || TO_BOOL mid) = let
					reflector = case axes of
						Inverse = reflectInverse
						Identity = reflectIdentity
						_ = reflectComplete
				in ({state&direction=reflector direction}, memory, world)
			| otherwise
				= (state, memory, world)
			
		reflectIdentity East = North
		reflectIdentity North = East
		reflectIdentity West = South
		reflectIdentity South = West
		
		reflectInverse East = South
		reflectInverse South = East
		reflectInverse West = North
		reflectInverse North = West
			
		reflectComplete East = West
		reflectComplete West = East
		reflectComplete South = North
		reflectComplete North = South
			
		axesCollide dir = case (axes, dir) of
			(Horizontal, East) = False
			(Horizontal, West) = False
			(Vertical, North) = False
			(Vertical, South) = False
			_ = True
		
	process (Control (Skip cond)) = skip
	where
		
		skip (state, memory=:{above={head={head=mid}}}, world)
			| cond || TO_BOOL mid
				= (TRAVERSE_ONE state, memory, world)
			| otherwise
				= (state, memory, world)
				
	process (Control (Turn rot)) = app3 (turn, id, id)
	where
		
		turn state=:{direction} = let
			dir = case (direction, rot) of
				(East, Clockwise) = South
				(East, Anticlockwise) = North
				(West, Clockwise) = North
				(West, Anticlockwise) = South
				(North, Clockwise) = East
				(North, Anticlockwise) = West
				(South, Clockwise) = West
				(South, Anticlockwise) = East
		in {state&direction=dir}

	process (Control (Loop Left dir (Just loc))) = loop
	where
		loop :: (!State, !Memory, !*World) -> (State, Memory, *World)
		loop smw=:(_, {left=Nothing}, _) = smw
		loop (state=:{direction}, memory=:{left=(Just left)}, world)
			| direction == dir
				= ({state&location=loc}, {memory&left=tailOf left}, world)
			| otherwise
				= (state, memory, world)
		
	process (Control (Loop Right dir (Just loc))) = loop
	where
		loop :: (!State, !Memory, !*World) -> (State, Memory, *World)
		loop smw=:(_, {right=Nothing}, _) = smw
		loop (state=:{direction}, memory=:{right=(Just right)}, world)
			| direction == dir
				= ({state&location=loc}, {memory&right=tailOf right}, world)
			| otherwise
				= (state, memory, world)
	
	process (Control (Goto dir (Just loc))) = goto
	where
		goto :: (!State, !Memory, !*World) -> (State, Memory, *World)
		goto (state=:{direction}, memory=:{above={head={head=mid}}}, world)
			| direction == dir && TO_BOOL mid
				= ({state&location=loc}, memory, world)
			| otherwise
				= (state, memory, world)
		
	process (Control (String)) = makeString
	where
		
		makeString (state=:{direction, location}, memory=:{above}, world)
			# (main, above) = decons above
			# main = recons (Just (fromStrictList [!fromInt el \\ el <- content] True), Just main)
			# above = recons (main, above)
			= (TRAVERSE_SOME (length content + newlineAdjust) state, {memory&above=above}, world)
		where
			
			delta => case direction of
				East = location.x+1
				West = dimension.x-location.x
				North = dimension.y-location.y
				South = location.y+1
				
			wrappedLine => let
				line => case direction of
					East = [c \\ c <-: source.[location.y]]
					West = reverse [c \\ c <-: source.[location.y]]
					North = reverse [src.[location.x] \\ src <-: source]
					South = [src.[location.x] \\ src <-: source]
			in line ++ ['\n'] ++ line
			
			newlineAdjust :: Int
			newlineAdjust => if(isMember 10 content) 0 1
			
			content :: [Int]
			content => (utf8ToUnicode o toString o takeWhile ((<>)'\'') o drop delta) wrappedLine
			
	process (Literal (Pi)) = app3 (id, \memory=:{above={head={head=mid}}} -> {memory&above={memory.above&head={memory.above.head&head=Just (recons (fromReal pi, mid))}}}, id)

	process (Literal (Quote)) = app3 (id, \memory=:{above={head={head=mid}}} -> {memory&above={memory.above&head={memory.above.head&head=Just (recons (fromInt (toInt '\''), mid))}}}, id)

	process (Literal (Digit val)) = literal
	where
	
		literal :: (!State, !Memory, !*World) -> (State, Memory, *World)
		
		literal (state=:{history}, memory=:{above}, world)
			# (main, above) = decons above
			# (mid, main) = decons main
			| isDigit history = let
				res = ((fromJust mid).head) * (fromInt 10) + val
				in (state, {memory&above=recons (recons (Just (recons (res, mid)), main), above)}, world)
			| otherwise = let
				in (state, {memory&above=recons (recons (Just (recons (val, mid)), main), above)}, world)
			
	process (Literal (Alphabet lettercase)) = app3 (id, \memory=:{above} -> {memory&above={above&head=recons (Just (fromStrictList literal True), Just above.head)}}, id)
	where
	
		literal :: [!Number]
		literal => case lettercase of
			Lowercase = [!fromInt (toInt c) \\ c <-: "abcdefghijklmnopqrstuvwxyz"]
			Uppercase = [!fromInt (toInt c) \\ c <-: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]

	process (Literal (EmptySet)) = app3 (id, \memory=:{above} -> {memory&above={above&head=recons (Nothing, Just above.head)}}, id)
				
	process (Variable (Random)) = app3 (id, rand, id)
	where
	
		rand memory=:{above, random=[rng:random]}
			# (main, above) = decons above
			# (mid, main) = decons main
			# mid = Just( recons (fromInt rng, mid))
			# main = recons (mid, main)
			# above = recons (main, above)
			= {memory&above=above, random=random}
	/*
	process (Variable (Quine)) = app3 (id, quine, id)
	where
		
		quine memory=:{delims, main} = {memory&cursor=delims,delims=inc delims,main=string + main}
			
		string => fromStrictList [!El (fromStrictList [!(fromInt o toInt) char \\ char <-: line] True) \\ line <-: source] True
	*/
	process (Environment env) = environment
	where
	
		environment (state, memory, world)
			# (memory, world) = env (memory, world)
			= (state, memory, world)
				
	process (Operator (IO_WriteAll)) = writeAll
	where
		
		writeAll (state, memory=:{above}, world)
			# (main, above) = decons above
			# (mid, main) = decons main
			# world = execIO (writeLine (fallback mid)) world
			= (state, {memory&above=recons (fallback main, above)}, world)
			
	process (Operator (IO_ReadAll)) = readAll
	where
		
		readAll (state, memory=:{above}, world)
			# (str, world) = readLine world
			# (main, above) = decons above
			# main = recons ( Just (fromList str True), Just main)
			= (state, {memory&above=recons (main, above)}, world)
		
	process (Operator (IO_WriteOnce)) = writeOnce
	where
	
		writeOnce (state, memory=:{above={head={head=Nothing}}}, world)
			= (state, memory, world)
			
		writeOnce (state, memory=:{above}, world)
			# (main, above) = decons above
			# (Just mid, main) = decons main
			# (top, mid) = decons mid
			# world = execIO (writeChar top) world
			= (state, {memory&above=recons (recons (mid, main), above)}, world)
				
	process (Operator (IO_ReadOnce)) = readOnce
	where
	
		readOnce (state, memory=:{above}, world)
			# (main, above) = decons above
			# (mid, main) = decons main
			# (chr, world) = readChar world
			= (state, {memory&above=recons (recons (Just (recons (chr, mid)), main), above)}, world)
	/*		
	process (Operator (IO_Interrobang)) = interrobang
	where
	
		interrobang (state, memory=:{main=main`=:{stack=[!El {stack=[!]}:other]}}, world)
			# (chr, world) = readChar world
			= (state, {memory&main={main`&stack=[!El (fromSingle chr):other]}}, world)
		interrobang (state, memory=:{main=main`=:{stack=[!El mid`=:{stack=[!top:mid]}:other]}}, world)
			# world = execIO (writeChar top) world
			# (chr, world) = readChar world
			= (state, {memory&main={main`&stack=[!El {mid`&stack=[!chr:mid]}:other]}}, world)
			
	process (Operator (IO_ClearConsole)) = app3 (id, id, clearConsole)
	*/
	process (Operator (Binary_NN_N inv op)) = app3 (id, binary, id)
	where
		
		binary :: !Memory -> Memory
		binary memory=:{left, right, above}
			#! mid = binary` flags.strict inv left` right` mid` 
			= {memory&left=left`,right=right`,above={above&head={above.head&head=mid}}}
		where
			mid` => sanitize above.head.head
			left` => sanitize left
			right` => sanitize right
		
		binary` :: !Bool !Bool !(MStack Number) !(MStack Number) !(MStack Number) -> (MStack Number)
		binary` _ _ memory=:{left=Just{head=lhs}, right=Just{head=rhs}}
			# (main, above) = decons memory.above
			# (mid, main) = decons main
			#! val = op lhs rhs
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` False _ memory=:{left=Just{head=lhs}, above={head={head=Just _}}, right=Nothing}
			# (main, above) = decons memory.above
			# (Just mid, main) = decons main
			# (top, mid) = decons mid
			#! val = op lhs top
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` False _ memory=:{left=Nothing, above={head={head=Just _}}, right=Just{head=rhs}}
			# (main, above) = decons memory.above
			# (Just mid, main) = decons main
			# (top, mid) = decons mid
			#! val = op top rhs
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` False _ memory=:{left=Nothing, above={head={head=Nothing}}, right=Just{head=rhs,init=[!lhs:_]}}
			# (main, above) = decons memory.above
			# (mid, main) = decons main
			#! val = op lhs rhs
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` False _ memory=:{left=Just{head=lhs,init=[!rhs:_]}, above={head={head=Nothing}}, right=Nothing}
			# (main, above) = decons memory.above
			# (mid, main) = decons main
			#! val = op lhs rhs
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` False True memory=:{left=Nothing, above={head={head=Just{init=[!_:_]}}}, right=Nothing}
			# (main, above) = decons memory.above
			# (Just mid, main) = decons main
			# (arg1, Just mid) = decons mid
			# (arg2, mid) = decons mid
			#! val = op arg1 arg2
			#! mid = recons (val, mid)
			= {memory&above=recons (recons (Just mid, main), above)}
		binary` _ _ memory = memory
		/*
	process (Operator (Binary_NN_S inv op)) = app3 (id, binary flags.strict inv, id)
	where // productive
		
		binary :: !Bool !Bool Memory -> Memory
		binary _ _ memory=:{delims, left={stack=[!lhs:_]}, right={stack=[!rhs:_]}}
			#! val = op lhs rhs
			= {memory&delims=inc delims,main=recon2 (El val, Delim delims, memory.main)}
		binary False _ memory=:{delims, left={stack=[!lhs:_]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			# (top, mid) = decons mid
			#! val = op lhs top
			= {memory&delims=inc delims,main=recon3 (El val, Delim delims, El mid, other)}
		binary False _ memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!rhs:_]}}
			# (El mid, other) = decons memory.main
			# (top, mid) = decons mid
			#! val = op top rhs
			= {memory&delims=inc delims,main=recon3 (El val, Delim delims, El mid, other)}
		binary False _ memory=:{delims, left={stack=[!lhs,rhs:_]}, main={stack=[!El {stack=[!]}:_]}, right={stack=[!]}}
			#! val = op lhs rhs
			= {memory&delims=inc delims,main=recon2 (El val, Delim delims, memory.main)}
		binary False _ memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!]}:_]}, right={stack=[!rhs,lhs:_]}}
			#! val = op lhs rhs
			= {memory&delims=inc delims,main=recon2 (El val, Delim delims, memory.main)}
		binary False True memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!_,_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			# (arg1, arg2, mid) = decon2 mid
			#! val = op arg1 arg2
			= {memory&delims=inc delims,main=recon3 (El val, Delim delims, El mid, other)}
		binary _ _ memory = memory
		
	process (Operator (Binary_SN_N op)) = app3 (id, binary flags.strict, id)
	where
	
		binary :: !Bool Memory -> Memory
		binary False memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!rhs:_]}}
			# (El mid, other) = decons memory.main
			#! val = op mid rhs
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary _ memory=:{left, right={stack=[!rhs:_]}}
			# (El mid, other) = decons memory.main
			#! val = op left rhs
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		binary False memory=:{left, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			# (top, mid) = decons mid
			#! val = op left top
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		binary _ memory = memory
		
	process (Operator (Binary_NS_N op)) = app3 (id, binary flags.strict, id)
	where
	
		binary :: !Bool Memory -> Memory
		binary False memory=:{left={stack=[!lhs:_]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op lhs mid
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary _ memory=:{left={stack=[!lhs:_]}, right}
			# (El mid, other) = decons memory.main
			#! val = op lhs right
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		binary False memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right}
			# (El mid, other) = decons memory.main
			# (top, mid) = decons mid
			#! val = op top right
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		binary _ memory = memory
		
	process (Operator (Binary_SS_N inv op)) = app3 (id, binary flags.strict inv, id)
	where
	
		binary :: !Bool !Bool Memory -> Memory
		binary False True memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]},El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, El oth, other) = decon2 memory.main
			#! val = op mid oth
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary False True memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op mid zero
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary False _ memory=:{left={stack=[!]}, main={stack=[!El {stack=[!]}:_]}, right={stack=[!]}}
			#! val = op zero zero
			#! mid = fromSingle val
			= {memory&main=recons (El mid, memory.main)}
		binary False _ memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right}
			# (El mid, other) = decons memory.main
			#! val = op mid right
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary False _ memory=:{left, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op left mid
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		binary _ _ memory=:{left, main, right}
			# (El mid, other) = decons memory.main
			#! val = op left right
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		
	process (Operator (Binary_SS_S inv op)) = app3 (id, binary flags.strict inv, id)
	where
	
		binary :: !Bool !Bool Memory -> Memory
		binary False True memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]},El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, El oth, other) = decon2 memory.main
			#! val = op mid oth
			= {memory&main=recons (El val, other)}
		binary False True memory=:{left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op mid zero
			= {memory&main=recons (El val, other)}
		binary False _ memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!]}:_]}, right={stack=[!]}}
			#! val = op zero zero
			= (MERGE_IF memory.main) {memory&delims=inc delims,main=recon2 (El val, Delim delims, memory.main)}
		binary False _ memory=:{left={stack=[!]}, main={stack=[!El{stack=[!_:_]}:_]}, right}
			# (El mid, other) = decons memory.main
			#! val = op mid right
			= {memory&main=recons (El val, other)}
		binary False _ memory=:{left, main={stack=[!El{stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op left mid
			= {memory&main=recons (El val, other)}
		binary _ _ memory=:{delims, left, main, right}
			#! val = op left right
			= {memory&delims=inc delims,main=recon2 (El val, Delim delims, main)}
			
	process (Operator (Binary_SS_T inv op)) = app3 (id, binary flags.strict inv, id)
	where
		
		binary :: !Bool !Bool Memory -> Memory
		binary False True memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!_:_]},El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, El oth, other) = decon2 memory.main
			#! val = op mid oth
			= (MERGE_IF other) {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, other)}
		binary False True memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op mid zero
			= (MERGE_IF other) {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, other)}
		binary False _ memory=:{delims, left={stack=[!]}, main={stack=[!El {stack=[!]}:_]}, right={stack=[!]}}
			#! val = op zero zero
			= {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, memory.main)}
		binary False _ memory=:{delims, left={stack=[!]}, main={stack=[!El{stack=[!_:_]}:_]}, right}
			# (El mid, other) = decons memory.main
			#! val = op mid right
			= (MERGE_IF other) {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, other)}
		binary False _ memory=:{delims, left, main={stack=[!El{stack=[!_:_]}:_]}, right={stack=[!]}}
			# (El mid, other) = decons memory.main
			#! val = op left mid
			= (MERGE_IF other) {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, other)}
		binary _ _ memory=:{delims, left, main, right}
			#! val = op left right
			= {memory&delims=inc delims,main=val + recons (Delim delims, main)}
			
	process (Operator (Unary_N_N op)) = app3 (id, unary, id)
	where
		
		unary :: Memory -> Memory
		unary memory=:{main={stack=[!El {stack=[!_:_]}:_]}}
			# (El mid, other) = decons memory.main
			# (arg, mid) = decons mid
			#! val = op arg
			#! mid = recons (val, mid)
			= {memory&main=recons (El mid, other)}
		unary memory = memory
		
	process (Operator (Unary_N_S op)) = app3 (id, unary, id)
	where
		
		unary :: Memory -> Memory
		//unary memory=:{delims, main=[El [arg]:other]}
		//	= {memory&delims=inc delims,main=[El (op arg),Delim delims: other]}
		unary memory=:{delims, main={stack=[!El {stack=[!_:_]}:_]}}
			# (El mid, other) = decons memory.main
			# (arg, mid) = decons mid
			#! val = op arg
			= {memory&delims=inc delims,main=recon3 (El val, Delim delims, El mid, other)}
		unary memory = memory
		
	process (Operator (Unary_S_N op)) = app3 (id, unary, id)
	where
	
		unary :: Memory -> Memory
		unary memory
			# (El mid, other) = decons memory.main
			#! val = op mid
			#! mid = fromSingle val
			= {memory&main=recons (El mid, other)}
		//unary memory = memory
		
	process (Operator (Unary_S_S op)) = app3 (id, unary, id)
	where
		
		unary :: Memory -> Memory
		unary memory
			# (El mid, other) = decons memory.main
			#! mid = op mid
			= {memory&main=recons (El mid, other)}
		//unary memory = memory
	
	process (Operator (Unary_S_T op)) = app3 (id, unary, id)
	where
		
		unary :: Memory -> Memory
		unary memory=:{delims, main}
			# (El mid, other) = decons main
			#! val = op mid
			= (MERGE_IF other) {memory&cursor=delims,delims=inc delims,main=val + recons (Delim delims, other)}*/
		
				
	process (Operator (Unary_M_M op)) = app3 (id, op, id)
			
