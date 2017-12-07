#[macro_use]
extern crate helix;

ruby! {
    class BootsnapNative {
        struct {
            x: i64
        }

        def initialize(helix, x: i64) {
            BootsnapNative { helix, x }
        }

        def thing(&self) -> i64 {
            self.x * 3
        }
    }
}
