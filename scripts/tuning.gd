extends RefCounted

const WALL_WIDTH := 3.0
const INITIAL_RADIUS := 174.0
const WALL_SPACING := 72.0
const WALL_COUNT := 4
const OUTER_RADIUS := INITIAL_RADIUS + (WALL_COUNT - 1) * WALL_SPACING
const GAP_ANGLE := 0.34
const TIP_ANGLE := -PI / 2.0
const TIP_LENGTH := 96.0
const TIP_EDGE_MARGIN := 0.03
const WHEEL_STEP := PI / 3.0
const TURN_DURATION := 0.16
const INITIAL_SPEED := 15.0
const MAX_SPEED := 32.0
const BOOST_MULTIPLIER := 3.4
const BREAK_TIME := 0.42
