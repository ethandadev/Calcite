//! On-device pairing for Calcite's built-in JIT (iOS 27+).
//!
//! iOS 27 lets the *device* start pairing with a computer: the computer advertises a
//! `_remotepairing-pairable-host._tcp` Bonjour service, the user picks it on the phone and types a
//! 6-digit code. Calcite plays the computer. This crate binds the TCP listener, exposes the
//! advertisement (service name + TXT records) to Objective-C, then runs idevice's `PairableHost`
//! (MIT, jkcoxson/idevice) and hands back the pairing plist.

use std::ffi::{c_char, c_void, CStr, CString};
use std::net::{Ipv4Addr, TcpListener};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

use idevice::remote_pairing::{PairableHost, PairableHostInfo, RpPairingFile, RpPairingSocket};
use tokio::sync::Notify;

const HOST_MODEL: &str = "Mac17,7";

pub struct CalcitePairing {
    port: u16,
    service_name: CString,
    txt: Vec<(CString, CString)>,
    listener: Mutex<Option<TcpListener>>,
    identity: Mutex<Option<(RpPairingFile, PairableHostInfo)>>,
    cancelled: AtomicBool,
    cancel: Notify,
}

pub type PinCallback = Option<extern "C" fn(pin: *const c_char, context: *mut c_void)>;

#[derive(Clone, Copy)]
struct PinTarget(PinCallback, *mut c_void);
unsafe impl Send for PinTarget {}
unsafe impl Sync for PinTarget {}

impl PinTarget {
    fn show(&self, pin: String) {
        if let (Some(cb), Ok(p)) = (self.0, CString::new(pin)) {
            cb(p.as_ptr(), self.1);
        }
    }
}

fn set_error(out: *mut *mut c_char, msg: impl Into<Vec<u8>>) {
    if !out.is_null() {
        unsafe { *out = CString::new(msg).unwrap_or_default().into_raw() };
    }
}

/// Create a session. Returns NULL on failure with `*error` set (free with `calcite_pairing_string_free`).
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_new(name: *const c_char, error: *mut *mut c_char) -> *mut CalcitePairing {
    if name.is_null() {
        set_error(error, "missing name");
        return ptr::null_mut();
    }
    let name = match CStr::from_ptr(name).to_str() {
        Ok(n) if !n.is_empty() => n.to_string(),
        _ => {
            set_error(error, "invalid name");
            return ptr::null_mut();
        }
    };
    let listener = match TcpListener::bind((Ipv4Addr::UNSPECIFIED, 0)) {
        Ok(l) => l,
        Err(e) => {
            set_error(error, format!("could not open a port: {e}"));
            return ptr::null_mut();
        }
    };
    let port = match listener.local_addr().and_then(|a| listener.set_nonblocking(true).map(|_| a.port())) {
        Ok(p) => p,
        Err(e) => {
            set_error(error, format!("could not open a port: {e}"));
            return ptr::null_mut();
        }
    };
    let file = RpPairingFile::generate(&name);
    let info = PairableHostInfo::generate(&name, HOST_MODEL);
    let id = file.identifier.clone();
    let txt = info
        .mdns_txt_records(&id)
        .into_iter()
        .filter_map(|(k, v)| Some((CString::new(k).ok()?, CString::new(v).ok()?)))
        .collect();
    Box::into_raw(Box::new(CalcitePairing {
        port,
        service_name: CString::new(id).unwrap_or_default(),
        txt,
        listener: Mutex::new(Some(listener)),
        identity: Mutex::new(Some((file, info))),
        cancelled: AtomicBool::new(false),
        cancel: Notify::new(),
    }))
}

#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_port(s: *const CalcitePairing) -> u16 {
    (*s).port
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_service_name(s: *const CalcitePairing) -> *const c_char {
    (*s).service_name.as_ptr()
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_txt_count(s: *const CalcitePairing) -> usize {
    (*s).txt.len()
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_txt_key(s: *const CalcitePairing, i: usize) -> *const c_char {
    (&*s).txt.get(i).map_or(ptr::null(), |(k, _)| k.as_ptr())
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_txt_value(s: *const CalcitePairing, i: usize) -> *const c_char {
    (&*s).txt.get(i).map_or(ptr::null(), |(_, v)| v.as_ptr())
}

enum Outcome {
    Cancelled,
    Failed(String),
}

/// Blocks until a device pairs, fails, or `calcite_pairing_cancel` is called.
/// `pin_cb` is called (on this thread) with the 6-digit code to display.
/// Returns 0 = success (`*out_plist`/`*out_len`, free with `calcite_pairing_bytes_free`), 1 = error, 2 = cancelled.
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_accept(
    s: *const CalcitePairing,
    pin_cb: PinCallback,
    pin_ctx: *mut c_void,
    out_plist: *mut *mut u8,
    out_len: *mut usize,
    error: *mut *mut c_char,
) -> i32 {
    let s = &*s;
    let listener = s.listener.lock().ok().and_then(|mut l| l.take());
    let identity = s.identity.lock().ok().and_then(|mut i| i.take());
    let (Some(listener), Some((file, info))) = (listener, identity) else {
        set_error(error, "this pairing session was already used");
        return 1;
    };
    let rt = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(rt) => rt,
        Err(e) => {
            set_error(error, format!("runtime error: {e}"));
            return 1;
        }
    };
    let target = PinTarget(pin_cb, pin_ctx);
    match rt.block_on(run(s, listener, file, info, target)) {
        Ok(file) => {
            let bytes = file.to_bytes().into_boxed_slice();
            if !out_len.is_null() {
                *out_len = bytes.len();
            }
            if !out_plist.is_null() {
                *out_plist = Box::into_raw(bytes) as *mut u8;
            }
            0
        }
        Err(Outcome::Cancelled) => 2,
        Err(Outcome::Failed(m)) => {
            set_error(error, m);
            1
        }
    }
}

async fn run(
    s: &CalcitePairing,
    listener: TcpListener,
    file: RpPairingFile,
    info: PairableHostInfo,
    target: PinTarget,
) -> Result<RpPairingFile, Outcome> {
    let listener = tokio::net::TcpListener::from_std(listener).map_err(|e| Outcome::Failed(format!("listen failed: {e}")))?;
    let pin_shown = std::sync::Arc::new(AtomicBool::new(false));
    let pair = async {
        let mut tasks = tokio::task::JoinSet::new();
        loop {
            tokio::select! {
                conn = listener.accept() => {
                    let (stream, addr) = conn.map_err(|e| Outcome::Failed(format!("accept failed: {e}")))?;
                    target.show(format!("EVT:The iPhone connected ({addr}). Starting the handshake…"));
                    let (mut f, i, shown) = (file.clone(), info.clone(), pin_shown.clone());
                    tasks.spawn(async move {
                        let mut host = PairableHost::new(RpPairingSocket::new_device(stream), i);
                        let res = host.accept(&mut f, |pin| {
                            shown.store(true, Ordering::SeqCst);
                            target.show(format!("PIN:{pin}"));
                            async {}
                        }).await.map(|_| f);
                        if let Err(e) = &res {
                            target.show(format!("EVT:Handshake error: {e}"));
                        }
                        res
                    });
                }
                Some(done) = tasks.join_next() => match done {
                    Ok(Ok(f)) => return Ok(f),
                    // Failing before a code was shown means a stray connection; keep waiting.
                    _ if !pin_shown.load(Ordering::SeqCst) => continue,
                    Ok(Err(e)) => return Err(Outcome::Failed(format!("pairing failed: {e}"))),
                    Err(e) => return Err(Outcome::Failed(format!("pairing failed: {e}"))),
                },
            }
        }
    };
    if s.cancelled.load(Ordering::SeqCst) {
        return Err(Outcome::Cancelled);
    }
    tokio::select! {
        biased;
        _ = s.cancel.notified() => Err(Outcome::Cancelled),
        r = pair => r,
    }
}

#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_cancel(s: *const CalcitePairing) {
    (*s).cancelled.store(true, Ordering::SeqCst);
    (*s).cancel.notify_one();
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_free(s: *mut CalcitePairing) {
    if !s.is_null() {
        drop(Box::from_raw(s));
    }
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_bytes_free(b: *mut u8, len: usize) {
    if !b.is_null() {
        drop(Box::from_raw(ptr::slice_from_raw_parts_mut(b, len)));
    }
}
#[no_mangle]
pub unsafe extern "C" fn calcite_pairing_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}
