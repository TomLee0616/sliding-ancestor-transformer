"""
人脸对齐：为指定的一对相邻阶段生成对齐输入。

把 stage-a 缩放+平移，使其人脸对齐到 stage-b，输出对齐后的 stage-a。
stage-b 保持原样。这样 RIFE 插值时两张图主体对齐，避免鬼影。

用法：
  python scripts/align_pair.py <frames_dir> <out_dir> <stage_a> <stage_b>
  例：python scripts/align_pair.py public/frames /tmp/out 3 4
  输出 /tmp/out/00.png (对齐后的 stage-3), /tmp/out/01.png (原始 stage-4)

如果人脸检测失败，stage-a 保持原样（不报错，让 RIFE 直接处理）。
"""
import os
import sys
import numpy as np
import cv2

TARGET = 800


def normalize(img, size=TARGET):
    """规整到 size×size（等比放大后居中裁切）"""
    h, w = img.shape[:2]
    scale = max(size / w, size / h)
    nw, nh = int(w * scale + 0.5), int(h * scale + 0.5)
    interp = cv2.INTER_AREA if scale < 1 else cv2.INTER_CUBIC
    img = cv2.resize(img, (nw, nh), interpolation=interp)
    x = (nw - size) // 2
    y = (nh - size) // 2
    return img[y:y + size, x:x + size].copy()


def detect_face(img):
    cascade_path = os.path.join(os.path.dirname(cv2.__file__), "data",
                                "haarcascade_frontalface_default.xml")
    cascade = cv2.CascadeClassifier(cascade_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5,
                                     minSize=(60, 60))
    if len(faces) == 0:
        faces = cascade.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3,
                                         minSize=(40, 40))
    if len(faces) == 0:
        return None
    x, y, fw, fh = max(faces, key=lambda f: f[2] * f[3])
    return (x + fw / 2.0, y + fh / 2.0, float(max(fw, fh)))


def align_to(img_src, face_src, face_dst, size):
    cx_s, cy_s, size_s = face_src
    cx_d, cy_d, size_d = face_dst
    scale = size_d / size_s
    tx = cx_d - cx_s * scale
    ty = cy_d - cy_s * scale
    M = np.array([[scale, 0, tx], [0, scale, ty]], dtype=np.float32)
    return cv2.warpAffine(img_src, M, (size, size),
                          borderMode=cv2.BORDER_REFLECT_101)


def main():
    frames_dir = sys.argv[1]
    out_dir = sys.argv[2]
    a = int(sys.argv[3])
    b = int(sys.argv[4])
    os.makedirs(out_dir, exist_ok=True)

    img_a = normalize(cv2.imread(os.path.join(frames_dir, f"stage-{a}.png")))
    img_b = normalize(cv2.imread(os.path.join(frames_dir, f"stage-{b}.png")))

    fa = detect_face(img_a)
    fb = detect_face(img_b)

    if fa and fb:
        img_a_aligned = align_to(img_a, fa, fb, TARGET)
        print(f"stage-{a} 对齐到 stage-{b}: 缩放 {fb[2]/fa[2]:.3f}")
    else:
        img_a_aligned = img_a
        print(f"stage-{a} 或 stage-{b} 人脸检测失败，使用原图")

    cv2.imwrite(os.path.join(out_dir, "00.png"), img_a_aligned)
    cv2.imwrite(os.path.join(out_dir, "01.png"), img_b)


if __name__ == "__main__":
    main()
