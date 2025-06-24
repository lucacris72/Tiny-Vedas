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
