#!/usr/bin/python3
# -*- coding: utf-8 -*-

import os
import json

def main():
    env_data = dict(os.environ)

    # Wypisz na konsolę
    print(json.dumps(env_data, indent=4))

    # Zapisz do pliku
    with open("/tmp/barracuda_event_dump.json", "w") as f:
        json.dump(env_data, f, indent=4)

if __name__ == "__main__":
    main()

