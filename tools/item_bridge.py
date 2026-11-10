"""Run the NOVA Item Editor's local export bridge without interrupting map exports."""
from map_bridge import main

if __name__ == "__main__":
    main(default_port=34873)
