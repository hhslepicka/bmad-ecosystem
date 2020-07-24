#pragma once
#include <vector>
#include <array>
#include <utility>
#include <tuple>
#include <string>
#ifdef G4MULTITHREADED
#include "G4MTRunManager.hh"
#else
#include "G4RunManager.hh"
#endif
#include "parser.hpp"
#include "bin.hpp"
#include "point_cache.hpp"

class CalibrationBinner {
  private:
    std::vector<GeantParticle> cal_run;
    std::vector<double> E_edges, r_edges;
    std::vector<std::vector<ERBin>> bins;
    size_t total_count, elec_in;
    G4RunManager* runManager;
    PointCache* point_cache;
    std::string target_material, out_dir;
    const double in_energy, target_thickness;
    G4ThreeVector in_polarization;

    std::pair<unsigned, unsigned> get_bin_num(double E, double r) const;
    void write_table(const std::string& param) const;

  public:
    CalibrationBinner() = delete;
    CalibrationBinner(G4RunManager*, PointCache*, const SimSettings&, double E, double T);
    CalibrationBinner(const CalibrationBinner&) = delete;
    CalibrationBinner& operator=(const CalibrationBinner&) = delete;

    void calibrate();
    void run(size_t run_length);
    void write_data();

    void add_point(const GeantParticle& p);
    double get_E_val(int n_E) const;
    double get_r_val(int n_r) const;
    ERBin& get_bin(int n_E, int n_r);
    const ERBin& get_bin(int n_E, int n_r) const;
    bool in_range(const GeantParticle& p) const;
    bool has_empty_bins() const;
    bool has_enough_data() const;
    inline size_t get_total() const { return total_count; }

};
