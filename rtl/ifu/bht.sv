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

// bht.sv
// Modulo per la Branch History Table con contatori a 2 bit a saturazione

module bht #(
    parameter BHT_ENTRIES = 1024
) (
    input  logic                          clk,
    input  logic                          rst_n,

    // Interfaccia di PREDIZIONE (usata in IFU)
    input  logic [31:0]                   predict_pc,
    output logic                          predict_taken,

    // Interfaccia di AGGIORNAMENTO (usata dopo la risoluzione del branch)
    input  logic                          update_en,      // Abilita l'aggiornamento
    input  logic [31:0]                   update_pc,      // PC del branch da aggiornare
    input  logic                          update_actual_taken // Esito reale del branch
);

    // La Branch History Table: un array di contatori a 2 bit.
    // Viene inizializzata a 'Weakly Not Taken' (01) al reset.
    logic [1:0] bht_table [0:BHT_ENTRIES-1];

    // --- Logica di Indicizzazione ---
    // Usiamo alcuni bit del PC per calcolare l'indice.
    // Ignoriamo i 2 bit meno significativi perché sono sempre '00' per istruzioni allineate.
    localparam BHT_INDEX_WIDTH = $clog2(BHT_ENTRIES);
    logic [BHT_INDEX_WIDTH-1:0] predict_index;
    logic [BHT_INDEX_WIDTH-1:0] update_index;

    assign predict_index = predict_pc[BHT_INDEX_WIDTH+1:2];
    assign update_index  = update_pc[BHT_INDEX_WIDTH+1:2];


    // --- Logica di PREDIZIONE (Combinatoria) ---
    // La predizione si basa sul bit più significativo (MSB) del contatore.
    // MSB = 1 -> Taken; MSB = 0 -> Not Taken.
    assign predict_taken = bht_table[predict_index][1];


    // --- Logica di AGGIORNAMENTO (Sequenziale) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Al reset, inizializziamo tutti i contatori a 'Weakly Not Taken' (01).
            for (int i = 0; i < BHT_ENTRIES; i++) begin
                bht_table[i] <= 2'b01;
            end
        end else begin
            if (update_en) begin
                // Aggiorna il contatore in base all'esito reale del branch
                case (bht_table[update_index])
                    // Strongly Not Taken
                    2'b00: bht_table[update_index] <= update_actual_taken ? 2'b01 : 2'b00;

                    // Weakly Not Taken
                    2'b01: bht_table[update_index] <= update_actual_taken ? 2'b10 : 2'b00;

                    // Weakly Taken
                    2'b10: bht_table[update_index] <= update_actual_taken ? 2'b11 : 2'b01;

                    // Strongly Taken
                    2'b11: bht_table[update_index] <= update_actual_taken ? 2'b11 : 2'b10;
                endcase
            end
        end
    end

endmodule
