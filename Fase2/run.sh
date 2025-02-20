#!/bin/sh
#
#SBATCH --partition cpar
#SBATCH --exclusive
#SBATCH --time=02:00
#SBATCH --cpus-per-task=40
module load gcc/11.2.0
make clean
make
make runpar

time ./fluid_sim
