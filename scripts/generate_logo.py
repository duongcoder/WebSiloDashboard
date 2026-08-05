import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_gradient_circle(size):
    # Supersampling 4x for ultra smooth quality
    scale = 4
    S = size * scale
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    
    # Create linear gradient background
    gradient = Image.new("RGBA", (S, S))
    c1 = (0x25, 0x63, 0xEB) # #2563EB (Royal Blue)
    c2 = (0x06, 0xB6, 0xD4) # #06B6D4 (Cyan)
    
    for y in range(S):
        for x in range(S):
            # Gradient along diagonal (top-left to bottom-right)
            t = (x + y) / (2.0 * S)
            t = max(0.0, min(1.0, t))
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)
            gradient.putpixel((x, y), (r, g, b, 255))
            
    # Circular mask
    mask = Image.new("L", (S, S), 0)
    mask_draw = ImageDraw.Draw(mask)
    padding = int(S * 0.02)
    mask_draw.ellipse((padding, padding, S - padding, S - padding), fill=255)
    
    # Apply mask
    circle_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    circle_img.paste(gradient, (0, 0), mask)
    
    # Draw insights icon (graph line + node points + stars)
    draw = ImageDraw.Draw(circle_img)
    
    # Coordinates normalized (0..1) relative to canvas size S
    # Points for graph trend
    pts = [
        (S * 0.28, S * 0.65),
        (S * 0.42, S * 0.52),
        (S * 0.56, S * 0.60),
        (S * 0.74, S * 0.40)
    ]
    
    line_width = int(S * 0.038)
    
    # Draw graph line
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill=(255, 255, 255, 255), width=line_width, joint="round")
        
    # Draw circular nodes at points
    node_radius = int(S * 0.045)
    for px, py in pts:
        draw.ellipse([px - node_radius, py - node_radius, px + node_radius, py + node_radius], fill=(255, 255, 255, 255))
        
    # Helper to draw 4-point star (sparkle)
    def draw_star(cx, cy, radius):
        # 4-pointed concave star path
        star_pts = []
        inner_r = radius * 0.28
        for k in range(8):
            angle = k * (math.pi / 4.0) - (math.pi / 2.0)
            r = radius if k % 2 == 0 else inner_r
            star_pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        draw.polygon(star_pts, fill=(255, 255, 255, 255))

    # Main top-right star
    draw_star(S * 0.73, S * 0.26, S * 0.08)
    
    # Secondary top-left star
    draw_star(S * 0.36, S * 0.35, S * 0.05)

    # Secondary bottom-right star
    draw_star(S * 0.78, S * 0.54, S * 0.04)

    # Resize down to target size with high quality resampling
    final_img = circle_img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def create_maskable_logo(size):
    scale = 4
    S = size * scale
    img = Image.new("RGBA", (S, S), (0x0F, 0x17, 0x2A, 255)) # Dark slate background #0F172A
    
    # Create smaller inner circle logo in safe zone
    inner_size = int(size * 0.8)
    inner_logo = create_gradient_circle(inner_size)
    inner_logo_scaled = inner_logo.resize((inner_size * scale, inner_size * scale), Image.Resampling.LANCZOS)
    
    offset = int((S - inner_size * scale) / 2)
    img.paste(inner_logo_scaled, (offset, offset), inner_logo_scaled)
    
    return img.resize((size, size), Image.Resampling.LANCZOS)

def main():
    web_dir = os.path.join(os.getcwd(), "web")
    icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(icons_dir, exist_ok=True)
    
    print("Generating 512x512 logo...")
    logo_512 = create_gradient_circle(512)
    logo_512.save(os.path.join(web_dir, "favicon.png"))
    logo_512.save(os.path.join(web_dir, "logo.png"))
    logo_512.save(os.path.join(icons_dir, "Icon-512.png"))
    
    print("Generating 192x192 logo...")
    logo_192 = create_gradient_circle(192)
    logo_192.save(os.path.join(icons_dir, "Icon-192.png"))
    
    print("Generating maskable icons...")
    maskable_512 = create_maskable_logo(512)
    maskable_512.save(os.path.join(icons_dir, "Icon-maskable-512.png"))
    
    maskable_192 = create_maskable_logo(192)
    maskable_192.save(os.path.join(icons_dir, "Icon-maskable-192.png"))
    
    print("Logo generation complete!")

if __name__ == "__main__":
    main()
