// Keyboard/mouse state with per-frame "just pressed" edges and pointer lock.
// Keyboard input works without pointer lock (as in Godot, where movement keys
// ignore the mouse mode); mouse look only applies while the pointer is locked.

export class Input {
  private down = new Set<string>();
  private pressed = new Set<string>();
  private released = new Set<string>();
  private mouseButtonsDown = new Set<number>();
  private mousePressed = new Set<number>();
  mouseDX = 0;
  mouseDY = 0;
  /** When false, gameplay ignores keys (e.g. while typing in the dev prompt). */
  enabled = true;
  /** Set while a UI element deliberately releases the pointer (dev menu). */
  suppressPause = false;
  readonly canvas: HTMLCanvasElement;
  private lockRequested = false;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    window.addEventListener("keydown", (e) => this.onKeyDown(e));
    window.addEventListener("keyup", (e) => {
      this.down.delete(e.code);
      this.released.add(e.code);
    });
    window.addEventListener("blur", () => {
      this.down.clear();
      this.mouseButtonsDown.clear();
    });
    document.addEventListener("mousemove", (e) => {
      if (!this.locked) return;
      this.mouseDX += e.movementX;
      this.mouseDY += e.movementY;
    });
    canvas.addEventListener("mousedown", (e) => {
      if (!this.locked) {
        if (e.button === 0) this.requestLock();
        return;
      }
      this.mouseButtonsDown.add(e.button);
      this.mousePressed.add(e.button);
    });
    window.addEventListener("mouseup", (e) => this.mouseButtonsDown.delete(e.button));
    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
    document.addEventListener("pointerlockchange", () => {
      this.lockRequested = false;
      if (!this.locked) this.mouseButtonsDown.clear();
    });
  }

  get locked(): boolean {
    return document.pointerLockElement === this.canvas;
  }

  requestLock(): void {
    if (this.locked || this.lockRequested) return;
    this.lockRequested = true;
    const result = this.canvas.requestPointerLock() as unknown;
    if (result instanceof Promise) result.catch(() => (this.lockRequested = false));
    window.setTimeout(() => (this.lockRequested = false), 1000);
  }

  releaseLock(): void {
    if (this.locked) document.exitPointerLock();
  }

  private onKeyDown(e: KeyboardEvent): void {
    const target = e.target as HTMLElement | null;
    if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
    if (["Space", "ArrowUp", "ArrowDown", "Tab", "F8"].includes(e.code)) e.preventDefault();
    if (!e.repeat) this.pressed.add(e.code);
    this.down.add(e.code);
  }

  isDown(code: string): boolean {
    return this.enabled && this.down.has(code);
  }

  justPressed(code: string): boolean {
    return this.enabled && this.pressed.has(code);
  }

  justReleased(code: string): boolean {
    return this.released.has(code);
  }

  mouseDown(button: number): boolean {
    return this.enabled && this.mouseButtonsDown.has(button);
  }

  mouseJustPressed(button: number): boolean {
    return this.enabled && this.mousePressed.has(button);
  }

  /** Debug/automation hook: simulate a key without a DOM event. */
  simulate(code: string, isDown: boolean): void {
    if (isDown) {
      if (!this.down.has(code)) this.pressed.add(code);
      this.down.add(code);
    } else {
      this.down.delete(code);
      this.released.add(code);
    }
  }

  /** Called at the end of each frame. */
  endFrame(): void {
    this.pressed.clear();
    this.released.clear();
    this.mousePressed.clear();
    this.mouseDX = 0;
    this.mouseDY = 0;
  }
}
