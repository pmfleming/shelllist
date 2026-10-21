use crate::command;
use std::{
    path::Path,
    time::{Duration, Instant},
};

#[test]
fn helper_timeout_is_bounded() {
    let sleep = command::resolve(Path::new("sleep")).unwrap();
    let start = Instant::now();
    let result = command::run(&sleep, &["10"], Duration::from_millis(25), false);
    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("timed out"));
    assert!(start.elapsed() < Duration::from_secs(2));
}
#[test]
fn helper_output_is_bounded() {
    let head = command::resolve(Path::new("head")).unwrap();
    let result = command::run(
        &head,
        &["-c", "2000000", "/dev/zero"],
        Duration::from_secs(2),
        false,
    );
    assert!(result.unwrap_err().to_string().contains("exceeds 1 MiB"));
}
#[test]
fn helper_arguments_are_not_shell_commands() {
    let printf = command::resolve(Path::new("printf")).unwrap();
    let value = "$(touch /not-executed); <script>";
    let result = command::run(&printf, &["%s", value], Duration::from_secs(2), false).unwrap();
    assert_eq!(result, value);
}
