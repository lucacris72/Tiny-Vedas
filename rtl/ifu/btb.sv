/*
 * Copyright (c) 2025 Luca Donato
 *
 * This file is part of a custom RISC-V core extension developed for a
 * project at Politecnico di Milano. It builds upon a base core
 * provided by Siliscale, licensed under the MIT License.
 *
 * --------------------------------------------------------------------------------
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


// btb.sv
// Modulo per il Branch Target Buffer

`ifndef GLOBAL_SVH
`include "global.svh"
`endif

module btb #(
    parameter BTB_ENTRIES     = 1024,
    parameter BTB_TAG_WIDTH   = 20,
    parameter XLEN            = 32
) (
    input  logic                          clk,
    input  logic                          rst_n,

    // --- Interfaccia di PREDIZIONE (usata in IFU) ---
    input  logic [XLEN-1:0]               predict_pc,
    output logic                          predict_hit,      // Esito: c'è stato un hit?
    output logic [XLEN-1:0]               predict_target_pc, // L'indirizzo di destinazione predetto

    // --- Interfaccia di AGGIORNAMENTO (dall'EXU) ---
    input  logic                          update_en,        // Abilita la scrittura/aggiornamento
    input  logic [XLEN-1:0]               update_pc,        // PC del branch da aggiornare
    input  logic [XLEN-1:0]               update_target_pc  // Indirizzo di destinazione calcolato
);

    // Larghezza dell'indice per accedere alla tabella
    localparam BTB_INDEX_WIDTH = $clog2(BTB_ENTRIES);

    // Definiamo la struttura di ogni entry del BTB
    typedef struct packed {
        logic              valid;
        logic [BTB_TAG_WIDTH-1:0] tag;
        logic [XLEN-1:0]   target_pc;
    } btb_entry_t;

    // La tabella del BTB: un array di entry
    btb_entry_t btb_table [0:BTB_ENTRIES-1];

    // --- Logica di Indicizzazione e Tag ---
    // Usiamo i bit del PC per derivare indice e tag.
    // L'indice usa i bit subito dopo i primi 2 (che sono sempre 00).
    // Il tag usa i bit successivi.
    logic [BTB_INDEX_WIDTH-1:0] predict_index;
    logic [BTB_TAG_WIDTH-1:0]   predict_tag;
    logic [BTB_INDEX_WIDTH-1:0] update_index;
    logic [BTB_TAG_WIDTH-1:0]   update_tag;

    assign predict_index = predict_pc[BTB_INDEX_WIDTH + 1 : 2];
    assign predict_tag   = predict_pc[BTB_INDEX_WIDTH + 2 + BTB_TAG_WIDTH - 1 : BTB_INDEX_WIDTH + 2];

    assign update_index  = update_pc[BTB_INDEX_WIDTH + 1 : 2];
    assign update_tag    = update_pc[BTB_INDEX_WIDTH + 2 + BTB_TAG_WIDTH - 1 : BTB_INDEX_WIDTH + 2];


    // --- Logica di PREDIZIONE (Combinatoria) ---
    // Leggiamo la entry corrispondente all'indice del PC di predizione
    btb_entry_t predict_entry;
    assign predict_entry = btb_table[predict_index];

    // C'è un "hit" se l'entry è valida e il tag corrisponde
    assign predict_hit = predict_entry.valid && (predict_entry.tag == predict_tag);

    // L'output è l'indirizzo di destinazione memorizzato in quella entry
    assign predict_target_pc = predict_entry.target_pc;


    // --- Logica di AGGIORNAMENTO (Sequenziale) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Al reset, invalida tutte le entry del BTB
            for (int i = 0; i < BTB_ENTRIES; i++) begin
                btb_table[i].valid <= 1'b0;
            end
        end else if (update_en) begin
            // Se l'aggiornamento è abilitato, scriviamo i nuovi dati nella tabella
            btb_table[update_index].valid     <= 1'b1;
            btb_table[update_index].tag       <= update_tag;
            btb_table[update_index].target_pc <= update_target_pc;
        end
    end

endmodule
