# Storage

Firebase storage and KingFisher

## Overview

Using the combination of KingFisher for displaying and Firebase Storage is powerfull. But the logic and the amount of code needed can be more than needed. The struct ``FireImage`` is created to encapsulate it entirely. Showing an image is now extremely easy.
 ```swift
 FireImage(id: "123456789", path: "User/123456789.png") {
    Image("PersonPlaceHolder")
     .resizable() // Important to add
}
```
