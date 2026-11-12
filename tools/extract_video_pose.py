"""Extract confidence-gated pose landmarks for animation reference, not ready-made mocap.
Requires mediapipe, opencv-python-headless, numpy. No footage/model weights are bundled.
Example: python tools/extract_video_pose.py --video clip.mp4 --model pose_landmarker.task --out report.json
"""
import argparse,json
from pathlib import Path
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

parser=argparse.ArgumentParser()
parser.add_argument("--video",required=True)
parser.add_argument("--model",required=True)
parser.add_argument("--out",required=True)
parser.add_argument("--fps",type=float,default=15)
parser.add_argument("--visibility",type=float,default=0.75)
parser.add_argument("--coverage",type=float,default=0.8)
args=parser.parse_args()
capture=cv2.VideoCapture(args.video)
source_fps=capture.get(cv2.CAP_PROP_FPS)
if not capture.isOpened() or source_fps<=0: raise SystemExit("Video could not be decoded")
options=vision.PoseLandmarkerOptions(base_options=python.BaseOptions(model_asset_path=args.model),
    running_mode=vision.RunningMode.VIDEO,num_poses=1,min_pose_detection_confidence=0.6,
    min_pose_presence_confidence=0.6,min_tracking_confidence=0.6)
critical=[11,12,13,14,15,16,23,24,25,26,27,28,29,30,31,32]
samples=[];frames=0;accepted=0;next_time=0.0
with vision.PoseLandmarker.create_from_options(options) as detector:
    while True:
        ok,frame=capture.read()
        if not ok:break
        timestamp=frames/source_fps
        frames+=1
        if timestamp+1e-6<next_time:continue
        next_time+=1/args.fps
        image=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
        result=detector.detect_for_video(image,int(timestamp*1000))
        if not result.pose_landmarks:
            samples.append({"time":round(timestamp,4),"accepted":False,"reason":"no person"});continue
        pose=result.pose_landmarks[0]
        confidence=min(float(pose[i].visibility or 0) for i in critical)
        valid=confidence>=args.visibility
        accepted+=int(valid)
        world=result.pose_world_landmarks[0]
        samples.append({"time":round(timestamp,4),"accepted":valid,"minimum_visibility":round(confidence,4),
            "world":[[round(p.x,5),round(p.y,5),round(p.z,5)] for p in world],
            "image":[[round(p.x,5),round(p.y,5)] for p in pose]})
capture.release()
coverage=accepted/max(1,len(samples))
report={"schema_version":1,"sample_fps":args.fps,"frames_sampled":len(samples),
    "accepted_frames":accepted,"coverage":coverage,"passed_quality_gate":coverage>=args.coverage,
    "status":"reference only: manual foot-contact, occlusion and retarget review required",
    "samples":samples}
Path(args.out).write_text(json.dumps(report,separators=(",",":")))
print(json.dumps({k:v for k,v in report.items() if k!="samples"}))
raise SystemExit(0 if coverage>=args.coverage else 2)
