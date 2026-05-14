# Medley Interlisp

** Upon further testing, some bugs have been discovered.  A correction is in progress.**


The Medley system is one of the retro implementations of the Interlisp language and programming environment. 
One of its chief differentiations is the fact that the core virtual machine (VM, Maiko) was written in the C language. 
This made it the only portable implementation.

Sometime around 2020, the system was made open-source. 
A team made up largely of the original Interlisp developers created a GitHub repository for the system and commenced work on it. 
That team still meets and works on the system regularly. Due to differing goals, priorities, and opinions, I have decided to fork their project and go my own way.

Given the interdependency of the Maiko VM and the Interlisp system, I have integrated the two into a single system.

I have been making extensive use of the Claude Code LLM/AI system to perform coding tasks. 
With this system, I have been able to accomplish in hours what would have taken weeks or months. 
My aim is to accomplish goals, and if the use of LLMs makes it faster and easier, I like it. 
Do LLMs make mistakes? Absolutely. But then again, so do software engineers. 
In the following projects, I will be acting more as a development manager than a developer. My use of LLMs involves:

1. Defining a project
2. Monitoring the project to assure things are done correctly
3. Extensive testing to assure it works

Some of my priorities include:

1. Simplify and correct system build (done)
2. Stop the system from pegging the CPU (done)
3. Port from a dependency on X11 (with some SDL2 support) to SDL3 (done)
4. Correct screen handling to support dynamic window sizes rather than a limited range of static window sizes (done)
5. Native ports to Linux, macOS and Windows (done)

The main home for this system is https://github.com/blakemcbride/MedleyInterlisp

