import os, json, socket, time, pathlib
sock=os.environ.get("HERDR_SOCKET_PATH","")
pane=os.environ.get("HERDR_PANE_ID","")
session=os.environ.get("_muse_herdr_session","") or os.environ.get("MUSE_SESSION_ID","")
if sock and pane:
    try:
        seq=time.time_ns()
        params={"pane_id":pane,"source":"herdr:muse","agent":"muse","seq":seq}
        if session:
            params["agent_session_id"]=session
            for cand in pathlib.Path(os.path.expanduser("~/.local/share/muse/sessions")).rglob(f"{session}/session.jsonl"):
                params["agent_session_path"]=str(cand)
                break
        req=json.dumps({"id":f"herdr:muse:{seq}","method":"pane.report_agent_session","params":params})
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            s.connect(sock)
            s.sendall((req+"\n").encode())
            s.recv(4096)
    except:
        pass
    try:
        seq=time.time_ns()
        params2={"pane_id":pane,"source":"herdr:muse","agent":"muse","state":"working","seq":seq}
        req2=json.dumps({"id":f"herdr:muse2:{seq}","method":"pane.report_agent","params":params2})
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            s.connect(sock)
            s.sendall((req2+"\n").encode())
            s.recv(4096)
    except:
        pass
