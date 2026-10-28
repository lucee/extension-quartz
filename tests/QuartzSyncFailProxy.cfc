/**
 * Test seam (not a test spec). A Quartz whose sync() always fails, to check that start()
 * leaves a scheduler that is already running in the state "running" (LDEV-6780).
 */
component extends="org.lucee.extension.quartz.Quartz" {

	private function sync( boolean async = false ) {
		throw "sync failed on purpose";
	}
}
