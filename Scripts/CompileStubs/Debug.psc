Scriptname Debug Hidden
{Compile-only stub. Never shipped; the game has the real script.}

Function Notification(String asMessage) native global
Bool Function OpenUserLog(String asLogName) native global
Function CloseUserLog(String asLogName) native global
Bool Function TraceUser(String asLogName, String asText, Int aiSeverity = 0) native global
