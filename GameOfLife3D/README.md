# GameOfLife3D
## Overview
This project implements John Conway's Game of Life, rendering multiple generations stacked together in 3D with camera controls to explore the space. This project is created with Claude Code AI assistance.
## Requirements
* The application runs from a users browser, and requires no extra software installation
* The application must support versions of FireFox, Chrome, and Edge from the year 2022 or newer.
* The application renders scenes in real time in the user's browser.
* Generations are rendered in the X-Y plane, with each generation in increasing Z order. For example generation one renders in X-Y with z=0, generation two renders in X-Y with z = 1
* Each bit is padded by 20% so that there is empty space between it and its neighbors in X,Y,Z. 
* The bit padding is user configurable in 0 to 100% , 1% increments.
* Users can load a starting generation as text files, or select from installed starting patterns. 
* Users can select the number of generations to render.
* Users can navigate the 3D space with keyboard camera controls
* Users can select the number of generations to display (starting to ending generation). Note this can be separate from (but must be within) the number of generations to render, this feature allows users to zoom in on a set of generations.
* Users can save their renderings to a text file on their PC (format to be determined)
* Users can load the saved renderings from text files on their PC
* The background will be a starfield rendered from actual star data as seen from Earth
* Bits that are turned on will be rendered as colored matte surface cubes
* Scene lighting will be 80% ambient and 20% directional
## Design
* The application uses WebGL and Typescript and renders in the browser.