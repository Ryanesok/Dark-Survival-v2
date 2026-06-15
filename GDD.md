# Game Design Document - Dark Survival v2

## 1. High Concept
Dark Survival v2 adalah game action survival 2D side-scrolling yang dibuat dengan Godot 4. Pemain mengendalikan karakter magi untuk bertahan hidup selama 90 detik, mengalahkan musuh sebanyak mungkin, dan menjaga kesehatan setinggi mungkin demi skor akhir yang lebih besar.

## 2. Design Pillars
- Aksi cepat dan mudah dibaca.
- Sesi singkat dengan nilai replay tinggi.
- Kontrol sederhana, tetapi tetap punya ruang skill melalui combo, dash, dan ultimate.
- Feedback yang jelas lewat HUD, animasi, dan layar hasil akhir.

## 3. Core Game Loop
1. Pemain memilih Play dari main menu.
2. Match dimulai di arena 2D.
3. Enemy spawner memunculkan musuh secara berkala.
4. Pemain bergerak, melompat, menyerang, dash, dan memakai ultimate.
5. Timer berjalan turun dari 90 detik.
6. Match selesai jika timer habis atau HP pemain habis.
7. Hasil akhir ditampilkan sebagai You Win atau Game Over, lalu pemain bisa restart atau kembali ke menu.

## 4. Controls
| Aksi | Input |
|---|---|
| Bergerak kiri/kanan | A / D |
| Lompat | Space |
| Serang | Mouse kiri |
| Dash | Mouse kanan |
| Ultimate | Q |
| Pause | Tombol pause / Escape |

## 5. Player Design
### 5.1 Statistik Dasar
- HP pemain: 100.
- Kecepatan jalan: 130.
- Kecepatan dash: 350.
- Durasi dash: 0.20 detik.
- Cooldown dash: 0.6 detik.
- Waktu pengisian ultimate penuh: 3 detik.

### 5.2 Combat Kit
Pemain memiliki beberapa opsi serangan:
- Basic attack combo 3 hit.
- Plunge attack saat menyerang di udara.
- Dash attack saat menyerang dari dash.
- Ultimate attack saat meter penuh.

### 5.3 Damage Pemain
- Basic attack 1: 3.2
- Basic attack 2: 2.5
- Basic attack 3: 6.0
- Dash attack: 7.0
- Plunge attack: 8.0
- Ultimate: 10.0

### 5.4 Combat Feel
- Combo dapat dibuffer supaya input terasa responsif.
- Dash bisa dipakai untuk repositioning dan, pada kondisi tertentu, untuk cancel combo.
- Kamera mengikuti gerakan pemain dengan look-ahead agar arah serangan terasa lebih dinamis.
- Ultimate memunculkan VFX tambahan dan hitbox lebar untuk memberi rasa ledakan serangan.

## 6. Enemy Design
### 6.1 Statistik Dasar
- HP musuh: 15.
- Kecepatan gerak: 48.
- Damage ke pemain: 15.

### 6.2 Behavior
Musuh memakai AI sederhana berbasis jarak:
- Jika pemain terlalu dekat, musuh masuk fase attack preparation.
- Jika pemain berada dalam jarak serang, musuh menyerang.
- Jika pemain cukup jauh, musuh bergerak mendekat.
- Jika pemain terlalu dekat untuk bergerak, musuh berhenti.

### 6.3 Combat Readability
- Musuh punya animasi idle, run, prepare attack, attack, get hit, dan die.
- Saat kena hit, musuh terdorong sedikit untuk memberi feedback visual.
- Musuh hilang dari scene saat animasi mati selesai.

## 7. Spawning And Pressure
- Enemy spawner memunculkan musuh dari sisi kiri atau kanan arena.
- Interval spawn pada scene utama: 2 detik.
- Batas musuh aktif: 8.
- Sistem ini mendorong tekanan konstan, tetapi masih memberi ruang bagi pemain untuk mengendalikan arena.

## 8. Round Rules
### 8.1 Win Condition
Pemain menang jika bertahan sampai timer mencapai 0.

### 8.2 Lose Condition
Pemain kalah jika HP habis sebelum waktu habis.

### 8.3 Pause And Restart
- Pause menu dapat dibuka dan ditutup selama ronde berjalan.
- Dari pause menu pemain bisa resume, restart, atau kembali ke main menu.
- Game over overlay menampilkan hasil akhir setelah ronde selesai.

## 9. Scoring
Skor akhir dihitung dari kesehatan tersisa dan jumlah musuh yang dikalahkan.

Rumus yang dipakai:
- Score = round(health percent) x enemies defeated

Implikasinya:
- Semakin tinggi HP akhir, semakin besar skor.
- Semakin banyak musuh yang dikalahkan, skor akan naik lebih cepat.
- Sistem ini mendorong pemain untuk tidak hanya bertahan hidup, tetapi juga agresif.

## 10. UI And Feedback
### 10.1 HUD In-Game
HUD menampilkan:
- Timer match.
- Health bar.
- Ultimate bar.
- Score.

### 10.2 Main Menu
Main menu saat ini memiliki:
- Play
- Credit
- Quit
- Panel credit yang bisa dibuka dan ditutup

### 10.3 Pause UI
Pause UI saat ini memiliki:
- Pause
- Resume
- Restart
- Menu

### 10.4 Game Over Overlay
Overlay hasil akhir menampilkan:
- You Win atau Game Over
- Score akhir
- Jumlah musuh yang dikalahkan

## 11. Scene Structure Summary
Scene utama terdiri dari:
- Player
- Camera2D yang menempel ke player
- Enemy contoh di scene
- EnemySpawner
- GameManager
- Killzone
- TileMap layer untuk background, decoration, dan midground
- Teks kontrol singkat di layar

## 12. Art And Presentation
Dari aset yang ada, arah presentasi game mengarah ke:
- Gaya pixel art.
- Palet gelap dan kontras tinggi.
- Font pixel tebal untuk judul dan UI.
- Karakter utama bertema magi.
- Musuh bertema hantu gelap.

## 13. Audio
Belum terlihat implementasi audio dari konteks workspace. Jika dikembangkan, prioritasnya adalah:
- SFX untuk serangan, hit, dash, dan mati.
- SFX UI untuk menu dan pause.
- Musik loop saat match.

## 14. Open Design Notes
- Narasi dan latar cerita belum terimplementasi jelas di kode, jadi GDD ini fokus pada gameplay.
- Sistem musuh masih sederhana dan cocok dijadikan dasar untuk variasi enemy type berikutnya.
- Skor masih berbasis survival dan eliminasi, sehingga cocok untuk mode arcade atau score chase.

## 15. Proposed Next Expansions
- Lebih banyak tipe musuh.
- Boss encounter.
- Progression antar ronde.
- Power-up atau item drop.
- Audio dan screen shake untuk memperkuat impact combat.
