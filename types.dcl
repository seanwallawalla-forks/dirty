definition module types

import StdMaybe, StdOverloaded, StdClass

:: Stack t
	= {
		head :: !t,
		init :: [!t],
		tail :: [!t],
		finite :: !Bool
	}
	
:: MStack t :== Maybe (Stack t)
	
:: XYPair
	= {
		x :: !Int,
		y :: !Int
	}
	
:: Program
	= {
		dimension :: !XYPair,
		source :: !{!{#Char}},
		commands :: !{!{!Command}},
		wrapping :: !Bool
	}	
	
:: State	
	= {
		direction :: !Direction,
		location :: !XYPair,
		history :: !Char,
		terminate :: !Bool
	}

:: Memory
	= {
		note :: !Number,
		left :: !MStack Number,//![Number],
		right :: !MStack Number,//![Number],
		above :: !Stack (Stack (MStack Number)),//![Element],
		below :: !MStack (Stack (MStack Number)),
		random :: ![Int]
	}
	
:: Element :== MStack Number
:: Region :== Stack Element
	
:: Flags
	= {
		debug :: !Bool,
		dump :: !Bool,
		nums :: !Bool,
		strict :: !Bool,
		native :: !Bool
	}

:: Numeric
	= Int !Int
	| Real !Real

:: Number
	= Zero
	| Re !(Magnitude Sign Numeric)
	| Im !(Magnitude Sign Numeric)
	| Cx !(Magnitude Directed Complex)
	| NaN

:: Magnitude inf fin
	= Fin !fin
	| Inf inf
	
:: Sign 
	= Positive
	| Negative
	
:: Complex
	= {
		re :: !Numeric,
		im :: !Numeric
	}
	
:: Directed
	= Directed
	
:: Command
	= Control ControlCommand
	| Literal LiteralCommand
	| Variable VariableCommand
	| Operator OperatorCommand
	| Environment (*(Memory, *World) -> *(Memory, *World))
	| PlaceHolder
	
:: ControlCommand
	= Terminate
	| Start Orientation
	| Change Direction 
	| Bounce Direction
	| Either Axes
	| Mirror Bool Axes
	| Skip Bool
	| Turn Rotation
	| Loop StackID Direction (Maybe XYPair)
	| Goto Direction (Maybe XYPair)
	| String
	| Restart
	| NOOP
	| LINE
	
:: Orientation
	= Dir Direction
	| Axis Axes
	
:: LiteralCommand
	= Pi
	| Quote
	| Digit !Number
	| Alphabet LetterCase
	| EmptySet
	
:: VariableCommand
	= Random
	| Quine
	| History
	
:: LetterCase
	= Uppercase
	| Lowercase
	
:: OperatorCommand
	= IO_WriteAll
	| IO_ReadAll
	| IO_ReadWrite
	| IO_WriteRead
	| IO_WriteOnce
	| IO_ReadOnce
	| IO_Interrobang
	| IO_Bell
	| IO_Timestamp
	| IO_Sleep
	| IO_ClearConsole
	| IO_Backspace
	| IO_Environment
	| Binary_NN_N !Bool (Number Number -> Number)
	| Binary_NN_E !Bool (Number Number -> (MStack Number))
	| Binary_EN_N ((MStack Number) Number -> Number)
	| Binary_EN_E ((MStack Number) Number -> (MStack Number))
	| Binary_NE_N (Number (MStack Number) -> Number)
	| Binary_NE_E (Number (MStack Number) -> (MStack Number))
	| Binary_EE_N !Bool ((MStack Number) (MStack Number) -> Number)
	| Binary_EE_E !Bool ((MStack Number) (MStack Number) -> (MStack Number))
	| Binary_EE_R !Bool ((MStack Number) (MStack Number) -> (Stack (MStack Number)))
	| Unary_N_N (Number -> Number)
	| Unary_N_E (Number -> (MStack Number))
	| Unary_E_N ((MStack Number) -> Number)
	| Unary_E_E ((MStack Number) -> (MStack Number))
	| Unary_E_R ((MStack Number) -> (Stack (MStack Number)))
	| Unary_M_M (Memory -> Memory)
	| Math_Logarithm
	| Math_DotProduct
	| Math_Sum
	| Math_Product
	| Math_Conjugate
	| Math_RealPart
	| Math_ImaginaryPart
	| Math_ImaginaryUnit
	| Math_ComplexSplit
	| Math_Reciprocal
	| Math_Minimum
	| Math_Maximum
	| Math_Permutations
	| Math_Combinations
	| Math_PrimeFactors
	| Math_GreatestCommonDivisor
	| Math_LeastCommonMultiple
	| Math_ConvertToBase
	| Math_ConvertFromBase
	| Math_Average
	| Bitwise_LeftShift
	| Bitwise_RightShift
	| Logic_Equality
	| Logic_Inequality
	| Logic_LessThan
	| Logic_GreaterThan
	| Logic_LessOrEqual
	| Logic_GreaterOrEqual
	| Logic_SetEquality
	| Logic_ElementOf
	| Logic_SubsetOrEqual
	| Logic_SubsetNotEqual
	| Logic_NotSubsetNorEqual
	| Logic_Any
	| Logic_All
	| Logic_IsOrdered
	| Logic_IsLowercase
	| Logic_IsUppercase
	| Logic_IsPrime
	| Logic_IsReal
	| Logic_IsFinite
	| Logic_IsInfinite
	| Logic_Negation
	| Logic_Coalesce
	| Vector_And
	| Vector_Or
	| Vector_Multiplication
	| Vector_Addition
	| Vector_Subtraction
	| Vector_Equality
	| Vector_LessThan
	| Vector_GreaterThan
	| Vector_LessOrEqual
	| Vector_GreaterOrEqual
	| Vector_Negation
	| Vector_ElementOf
	| Range_FromLeftStepRight
	| Range_FromMiddleToZero
	| Range_FromMiddleAvoidZero
	| Range_FromLeftTimesRight
	| Set_PowerSet
	| Set_Subsets
	| Set_Permutations
	| Set_Combinations
	| Set_MakeOrdered
	| Set_Length
	| Set_Filter
	| Set_AntiFilter
	| Set_Intersection
	| Set_Union
	| Set_Minimum
	| Set_Maximum
	| Set_Exclusion
	| Chars_ToLowercase
	| Chars_ToUppercase
	| Chars_JoinWithNewlines
	| Chars_SplitOnNewlines

:: Rotation
	= Clockwise
	| Anticlockwise
	
:: StackID
	= Middle
	| Left
	| Right
	| Both
	| Primary
	| Base
	| Main
	| Every
	
:: Axes
	= Reflection
	| Inverse
	| Identity
	| Vertical
	| Horizontal
	
:: Direction
	= North
	| South
	| East
	| West
	| NorthWest
	| NorthEast
	| SouthWest
	| SouthEast