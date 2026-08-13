"""
人脸对齐预处理：对 6 张阶段代表图做人脸对齐，输出主体位置一致的对齐序列。

策略（统一基准）：
  选择一个基准图（默认 stage-5，即最终形态宁祖），检测每张图的人脸，
  把所有图都仿射变换（缩放+平移）使其人脸中心与尺寸对齐到基准。
  这样 6 张图的人物主体位置完全一致，RIFE 全局插值时不会因主体
  缩放/位移差异产生鬼影，过渡更顺滑。

  仅对齐位置和尺寸，不改变表情、装饰、气质——这些差异正是 RIFE
  擅长处理的细微形变。

  如果某张图检测不到人脸，保留原图不动（避免破坏）。

用法：
  python scripts/align_faces.py [input_dir] [output_dir]
  默认输入 public/frames，输出 output/aligned-frames
"""
import os
import sys
import numpy as np
import cv2

TARGET = 800


def detect_face(img):
    """用 Haar 级联检测最大人脸，返回 (cx, cy, size) 或 None"""
    cascade_path = os.path.join(os.path.dirname(cv2.__file__), "data",
                                "haarcascade_frontalface_default.xml")
    cascade = cv2.CascadeClassifier(cascade_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5,
                                     minSize=(60, 60))
    if len(faces) == 0:
        # 放宽参数重试
        faces = cascade.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3,
                                         minSize=(40, 40))
    if len(faces) == 0:
        return None
    x, y, fw, fh = max(faces, key=lambda f: f[2] * f[3])
    return (x + fw / 2.0, y + fh / 2.0, float(max(fw, fh)))


def align_to(img_src, face_src, face_dst, size):
    """缩放+平移 img_src，使 face_src 对齐到 face_dst"""
    cx_s, cy_s, size_s = face_src
    cx_d, cy_d, size_d = face_dst
    scale = size_d / size_s
    tx = cx_d - cx_s * scale
    ty = cy_d - cy_s * scale
    M = np.array([[scale, 0, tx], [0, scale, ty]], dtype=np.float32)
    return cv2.warpAffine(img_src, M, (size, size),
                          borderMode=cv2.BORDER_REFLECT_101)


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


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    in_dir = os.path.normpath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(root, "public", "frames")
    out_dir = os.path.normpath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(root, "output", "aligned-frames")
    BASELINE = 5  # 基准图索引（stage-5 宁祖）

    os.makedirs(out_dir, exist_ok=True)

    # 读入并规整 6 张图
    stages = []
    for i in range(6):
        p = os.path.join(in_dir, f"stage-{i}.png")
        if not os.path.exists(p):
            print(f"错误：找不到 {p}", file=sys.stderr)
            sys.exit(1)
        stages.append(normalize(cv2.imread(p)))

    # 检测每张图的人脸
    faces = []
    for i, img in enumerate(stages):
        f = detect_face(img)
        faces.append(f)
        print(f"stage-{i} 人脸: {f}" if f else f"stage-{i} 未检测到人脸")

    baseline_face = faces[BASELINE]
    if baseline_face is None:
        # 基准图检测失败，退而求其次：用第一个检测到人脸的图
        for i, f in enumerate(faces):
            if f is not None:
                BASELINE = i
                baseline_face = f
                break
    if baseline_face is None:
        print("警告：所有图都未检测到人脸，跳过对齐，直接输出规整后的图", file=sys.stderr)
        baseline_face = None

    print(f"基准图：stage-{BASELINE} 人脸 {baseline_face}")

    # 对齐每张图到基准
    for i, img in enumerate(stages):
        if baseline_face and faces[i] is not None and i != BASELINE:
            out = align_to(img, faces[i], baseline_face, TARGET)
            print(f"stage-{i} -> 对齐到 stage-{BASELINE}: 缩放 {baseline_face[2]/faces[i][2]:.3f}")
        else:
            out = img
            if i == BASELINE:
                print(f"stage-{i} (基准，保持原样)")
            else:
                print(f"stage-{i} 未对齐（人脸检测失败），使用规整后的原图")
        cv2.imwrite(os.path.join(out_dir, f"stage-{i}.png"), out)

    print(f"已输出对齐后的 6 张图到 {out_dir}")


if __name__ == "__main__":
    main()
