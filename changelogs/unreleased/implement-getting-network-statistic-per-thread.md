## feature/core

 * Getting network statistics per thread was implemented. User has
   possibility to run several iproto threads, but at the moment he
   can get only general statistics, which combines statistics for
   all threads. Now `box.stat.net.thread` has been implemented to get
   the same statistics as when using `box.stat.net`, but for a thread.
   User can call `box.stat.net.thread()` as a function to get general
   network statistics per threads or indexed it as a table by thread
   number to get network statistics for appropriate iproto thead.