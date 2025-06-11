class RopeWindController : Actor {
 default {
    //$Title "Rope wind controller"
    //$Sprite "ROPEC0"
    //$Icon "ROPEC0"
    //$Color 15
    //$Category "Ropes"
    //$IgnoreRenderstyle

    //$Arg0 "Rope controllers"
    //$Arg0Type 14
    //$Arg0Tooltip "The TID of the rope controllers to provide wind for."

    //$Arg2 "Maximum magnitude"
    //$Arg2Type 0
    //$Arg2Tooltip "The maximum magnitude in hundreth of units."

    //$Arg3 "Maximum magnitude change"
    //$Arg3Type 0
    //$Arg3Tooltip "The maximum amount to change the magnitude by in hundreth of units."

    //$Arg4 "Magnitude change delay"
    //$Arg4Type 0
    //$Arg4Tooltip "How many octics between changing the wind magnitude."

    radius 16;
    height 16;
    mass 0;
    renderstyle "STYLE_None";

    +NOGRAVITY
    +NONSHOOTABLE
    +NOINTERACTION
    +SYNCHRONIZED
  }

  States {
    Spawn:
      TNT1 A 8 Update();
      Loop;
  }

  int magnitude;
  int countdown;

  override void PostBeginPlay() {
    super.PostBeginPlay();

    countdown = 0;

    // The initial magnitude is half of the maximum.
    int magMax = args[2];
    magnitude = magMax / 2;
  }

  void update() {
    countdown -= 1;
    if (countdown > 0) {
      return;
    }
    countdown = args[4];

    // Change the magnitude.
    int magChange = args[3];
    int change = random(-magChange, magChange);
    magnitude += change;

    // Clamp the magnitude.
    int magMax = args[2];
    magnitude = min(max(magnitude, 0), magMax);

    // Calculate a new wind vector from the magnitude and controller angle.
    Vector2 dir = AngleToVector(angle, Double(magnitude) / 100.0);
    Vector3 wind = (dir.x, dir.y, 0);

    // Update rope controller wind vectors.
    RopeController controller;
    ActorIterator it = Level.CreateActorIterator(args[0], "RopeController");
    while (controller = RopeController(it.Next())) {
      controller.wind = wind;
    }
  }
}
