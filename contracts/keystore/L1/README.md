```asciiarmor
                   xxxxxxxx
                 xxx      x    xxxxxx
               xxx        xxxxxx     x
               xxx        xx        xxxxxxx
             xxxx     operation     x     x
            xxxx            x             x
          xx      xxx   xxxxx            xx
          x      xx xxxx    xxxxxxxxxxxxxx
           xxxxxx   │               │
                    │               │
                    │               │
                    │               │
                    ▼               ▼
┌──────────────────────┐         ┌───────────────────────┐
│                      │         │                       │
│     KeyStoreEOA      │         │  KeyStoreMekleTree    │
│                      │         │                       │
│   (one EOA signer)   │         │  (infinity signer)    │
│                      │         │                       │
└───────────┬──────────┘         └───────────┬───────────┘
            │                                │
            │                                │
            │     ┌──────────────────┐       │
            └────►│                  │◄──────┘
                  │   BaseKeyStore   │
                  │                  │
                  └─────────┬────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │                   │
                  │  KeyStoreStorage  │
                  │                   │
                  └───────────────────┘
```